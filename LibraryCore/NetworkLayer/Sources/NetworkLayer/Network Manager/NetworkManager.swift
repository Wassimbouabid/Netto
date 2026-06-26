//
//  NetworkManager.swift
//

import Foundation
internal import Alamofire
internal import CocoaLumberjackSwift

/// Concrete `NetworkService` powered by Alamofire.
///
/// Instantiated and lifecycle-managed by `NetworkContainer`. Do not create
/// instances directly — use `NetworkContainer.shared.makeNetworkService()`.
///
/// **Timeout priority**
/// 1. Per-endpoint `timeout` (if set on `APIEndpoint`)
/// 2. Session-level `requestTimeout` from `NetworkConfiguration` (default 30 s)
final class NetworkManager: NetworkService {

    // MARK: - Dependencies

    private let preRequestHandler: any PreRequestHandler
    private let responseHandler: any ResponseHandler
    private let errorHandler: any NetworkErrorHandler
    private let logger: any NetworkLogger
    private let connectivityMonitor: any NetworkMonitor

    // MARK: - Properties

    private let baseURL: URL
    private let session: Session
    private let isLoggingEnabled: Bool

    // MARK: - Initialisation

    init(
        baseURL: URL,
        session: Session,
        preRequestHandler: any PreRequestHandler,
        responseHandler: any ResponseHandler,
        errorHandler: any NetworkErrorHandler,
        logger: any NetworkLogger,
        connectivityMonitor: any NetworkMonitor,
        enableLogging: Bool = true
    ) {
        self.baseURL             = baseURL
        self.session             = session
        self.preRequestHandler   = preRequestHandler
        self.responseHandler     = responseHandler
        self.errorHandler        = errorHandler
        self.logger              = logger
        self.connectivityMonitor = connectivityMonitor
        self.isLoggingEnabled    = enableLogging
        connectivityMonitor.startMonitoring()
    }

    // MARK: - NetworkService

    func request<T: Decodable>(_ endpoint: any APIEndpoint, responseType: T.Type) async throws -> T {
        let (data, _) = try await execute(endpoint)
        return try responseHandler.decode(data, as: responseType)
    }

    func requestWithResponse<T: Decodable>(_ endpoint: any APIEndpoint, responseType: T.Type) async throws -> NetworkResponse<T> {
        let (data, httpResponse) = try await execute(endpoint)
        let body    = try responseHandler.decode(data, as: responseType)
        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                acc[key] = value
            }
        }
        return NetworkResponse(body: body, headers: headers, statusCode: httpResponse.statusCode)
    }

    func requestWithoutResponse(_ endpoint: any APIEndpoint) async throws {
        _ = try await execute(endpoint)
    }

    func cancelAllRequests() {
        session.cancelAllRequests()
    }

    // MARK: - Private

    /// Core execution pipeline shared by all public methods.
    ///
    /// Handles connectivity checks, pre-request preparation, Alamofire dispatch,
    /// logging, response validation, and error normalisation.
    /// Returns the raw `(Data, HTTPURLResponse)` pair for callers to interpret.
    private func execute(_ endpoint: any APIEndpoint) async throws -> (Data, HTTPURLResponse) {
        guard connectivityMonitor.isConnected else {
            throw NetworkError.noInternet
        }

        let effectiveBaseURL = endpoint.customBaseURL ?? baseURL
        var apiRequest = APIRequest(endpoint: endpoint, baseURL: effectiveBaseURL)

        if !endpoint.skipsPreRequestHandler {
            try await preRequestHandler.prepare(&apiRequest)
        }

        let startTime = Date()

        if isLoggingEnabled { logger.logRequest(apiRequest) }

        // Captured once the HTTPURLResponse is available; forwarded to the error
        // handler so any error (AF-level or otherwise) can carry the server's headers.
        var responseHeaders: [String: String]? = nil

        do {
            let alamofireRequest = try createAlamofireRequest(from: apiRequest)
                        
            let responseData     = try await alamofireRequest.serializingData().value
            let duration         = Date().timeIntervalSince(startTime)

            guard let httpResponse = alamofireRequest.response else {
                throw NetworkError.invalidResponse
            }

            responseHeaders = httpResponse.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    acc[key] = value
                }
            }

            if isLoggingEnabled {
                logger.logResponse(responseData, response: httpResponse, for: apiRequest, duration: duration)
            }

            try responseHandler.validate(responseData, response: httpResponse)
            return (responseData, httpResponse)

        } catch {
            if isLoggingEnabled {
                logger.logError(error, for: apiRequest, duration: Date().timeIntervalSince(startTime))
            }
            throw errorHandler.handle(error, responseHeaders: responseHeaders)
        }
    }

    /// Builds an Alamofire `DataRequest` from the internal `APIRequest`.
    ///
    /// - Throws: `NetworkError.invalidURL` for a malformed URL (never crashes).
    private func createAlamofireRequest(from apiRequest: APIRequest) throws -> DataRequest {
        guard let url = URL(string: apiRequest.url) else {
            throw NetworkError.invalidURL
        }

        var headers = HTTPHeaders()
        apiRequest.headers?.forEach { headers.add(name: $0.key, value: $0.value) }

        // Multipart/form-data — uses session.upload which streams parts efficiently
        if case .multipart(let parts) = apiRequest.encoding {
            let formData = parts.toAlamofireMultipartFormData()
            if let timeout = apiRequest.timeout {
                return session.upload(
                    multipartFormData: formData,
                    to: url,
                    method: apiRequest.method.toAlamofire(),
                    headers: headers,
                    requestModifier: { $0.timeoutInterval = timeout }
                )
            }
            return session.upload(
                multipartFormData: formData,
                to: url,
                method: apiRequest.method.toAlamofire(),
                headers: headers
            )
        }

        // Custom encoding (escape hatch for exotic request mutations)
        if case .custom(let customEncoder) = apiRequest.encoding {
            return session.request(
                url,
                method: apiRequest.method.toAlamofire(),
                headers: headers,
                requestModifier: { urlRequest in
                    try customEncoder(&urlRequest)
                    if let timeout = apiRequest.timeout {
                        urlRequest.timeoutInterval = timeout
                    }
                }
            )
        }

        // Standard encoding (JSON / URL) with optional per-request timeout
        if let timeout = apiRequest.timeout {
            return session.request(
                url,
                method: apiRequest.method.toAlamofire(),
                parameters: apiRequest.parameters,
                encoding: apiRequest.encoding.toAlamofire(),
                headers: headers,
                requestModifier: { $0.timeoutInterval = timeout }
            )
        }

        return session.request(
            url,
            method: apiRequest.method.toAlamofire(),
            parameters: apiRequest.parameters,
            encoding: apiRequest.encoding.toAlamofire(),
            headers: headers
        )
    }
}
