//
//  MediaDownloadServiceImpl.swift
//  Netto
//
//  Created by Bouabid Wassim on 30/12/2025.
//

import Foundation
internal import Alamofire
internal import CocoaLumberjackSwift

final class MediaDownloadServiceImpl: MediaDownloadService {

    // MARK: - Dependencies

    private let session: Session
    /// When non-nil the handler runs before every download to attach
    /// auth headers (e.g. `Authorization: Bearer …`).
    private let preRequestHandler: (any PreRequestHandler)?

    // MARK: - Initialization

    init(configuration: NetworkConfiguration, preRequestHandler: (any PreRequestHandler)? = nil) {
        self.session            = NetworkSessionConfiguration.createSession(with: configuration)
        self.preRequestHandler  = preRequestHandler
    }

    // MARK: - MediaDownloadService

    func downloadMedia(_ request: MediaDownloadRequest) async -> MediaDownloadResult {
        guard let url = URL(string: request.url), url.scheme != nil else {
            DDLogError("Invalid URL for download: \(request.url)")
            return .failure(error: NetworkError.invalidURL)
        }

        DDLogInfo("Starting download: \(request.id) from \(request.url)")

        do {
            let headers = try await resolvedHeaders(for: request.url)
            let data = try await downloadWithRetry(
                from: url,
                headers: headers,
                requestId: request.id,
                maxRetryAttempts: request.maxRetryAttempts
            )
            DDLogInfo("Successfully downloaded: \(request.id) (\(data.count) bytes)")
            return .success(data: data)

        } catch {
            DDLogError("Failed to download \(request.id): \(error)")
            return .failure(error: error)
        }
    }

    func downloadMultipleMedia(_ requests: [MediaDownloadRequest]) async -> [MediaDownloadRequest: MediaDownloadResult] {
        guard !requests.isEmpty else { return [:] }

        DDLogInfo("Starting batch download of \(requests.count) media files")

        var results: [MediaDownloadRequest: MediaDownloadResult] = [:]

        let batchSize = 3
        let batches   = requests.chunked(into: batchSize)

        for batch in batches {
            await withTaskGroup(of: (MediaDownloadRequest, MediaDownloadResult).self) { group in
                for request in batch {
                    group.addTask { [weak self] in
                        guard let self else {
                            return (request, .failure(error: NetworkError.unknown(underlying: nil)))
                        }
                        return (request, await self.downloadMedia(request))
                    }
                }

                for await (request, result) in group {
                    results[request] = result
                }
            }
        }

        let successCount = results.values.filter { if case .success = $0 { true } else { false } }.count
        DDLogInfo("Completed batch download: \(successCount)/\(requests.count) successful")

        return results
    }
}

// MARK: - Private Helpers

private extension MediaDownloadServiceImpl {

    /// Runs the pre-request handler (if enabled) and returns any headers it attached.
    /// Returns `nil` when pre-request handling is disabled.
    func resolvedHeaders(for rawURL: String) async throws -> [String: String]? {
        guard let handler = preRequestHandler else { return nil }
        var apiRequest = APIRequest(rawURL: rawURL)
        try await handler.prepare(&apiRequest)
        return apiRequest.headers
    }

    /// Returns `true` for transient failures worth retrying (timeouts, dropped
    /// connections, DNS hiccups, 5xx/408/429). Client errors such as 403/404
    /// are permanent — retrying them only delays the failure.
    func isRetryable(_ error: Error) -> Bool {
        if let afError = error as? AFError {
            if case .responseValidationFailed(let reason) = afError,
               case .unacceptableStatusCode(let code) = reason {
                return code >= 500 || code == 408 || code == 429
            }
            if let urlError = afError.underlyingError as? URLError {
                return isRetryable(urlError)
            }
            return false
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        return false
    }

    func downloadWithRetry(
        from url: URL,
        headers: [String: String]?,
        requestId: String,
        maxRetryAttempts: Int,
        attempt: Int = 1
    ) async throws -> Data {
        do {
            return try await performDownload(from: url, headers: headers)
        } catch {
            guard attempt < maxRetryAttempts, isRetryable(error) else { throw error }
            let delay = TimeInterval(attempt)
            DDLogWarn("Download attempt \(attempt) failed for \(requestId), retrying in \(delay)s…")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await downloadWithRetry(
                from: url,
                headers: headers,
                requestId: requestId,
                maxRetryAttempts: maxRetryAttempts,
                attempt: attempt + 1
            )
        }
    }

    func performDownload(from url: URL, headers: [String: String]?) async throws -> Data {
        var afHeaders = HTTPHeaders()
        headers?.forEach { afHeaders.add(name: $0.key, value: $0.value) }

        return try await withCheckedThrowingContinuation { continuation in
            session.request(url, headers: afHeaders.isEmpty ? nil : afHeaders)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):  continuation.resume(returning: data)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
        }
    }
}

// MARK: - Array + chunked (private to this file)

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
