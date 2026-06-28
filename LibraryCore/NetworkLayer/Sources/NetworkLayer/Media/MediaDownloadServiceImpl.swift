//
//  MediaDownloadServiceImpl.swift
//  RevampCarSharing
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
