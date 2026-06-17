//
//  NetworkLogger.swift
//

import Foundation

// MARK: - NetworkLogger

/// Provides logging capabilities for network requests and responses.
///
/// Implement this protocol and register it via `NetworkServiceBuilder.withLogger(_:)`
/// to integrate with any logging framework (OSLog, SwiftyBeaver, your analytics, etc.):
///
/// ```swift
/// struct OSNetworkLogger: NetworkLogger {
///     func logRequest(_ request: APIRequest) {
///         Logger.network.debug("→ \(request.method.rawValue) \(request.url)")
///     }
///     // …
/// }
///
/// NetworkServiceBuilder(configuration: config)
///     .withLogger(OSNetworkLogger())
///     .build()
/// ```
public protocol NetworkLogger {
    /// Logs a network request that is about to be sent.
    func logRequest(_ request: APIRequest)

    /// Logs a successful network response.
    ///
    /// - Parameters:
    ///   - data: The raw response body, if any.
    ///   - response: The HTTP response metadata.
    ///   - request: The originating request.
    ///   - duration: Time elapsed from sending to receiving the response.
    func logResponse(_ data: Data?, response: HTTPURLResponse?, for request: APIRequest, duration: TimeInterval)

    /// Logs a network error.
    ///
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - request: The request that failed.
    ///   - duration: Time elapsed before the error occurred.
    func logError(_ error: Error, for request: APIRequest, duration: TimeInterval)
}
