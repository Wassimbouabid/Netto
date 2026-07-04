//
//  NetworkErrorHandler.swift
//  Netto
//
//  Created by Bouabid Wassim on 26/12/2025.
//

import Foundation

/// Protocol defining how network errors should be handled.
///
/// The `NetworkErrorHandler` is responsible for translating low-level
/// networking errors into application-specific `NetworkError` types.
public protocol NetworkErrorHandler {
    /// Translates any error to a `NetworkError`, optionally attaching HTTP response headers.
    ///
    /// `responseHeaders` should be the headers from the HTTP response that triggered the
    /// error (if one was received). They are embedded into the resulting `NetworkError`
    /// so callers can read them via `NetworkError.responseHeaders`.
    ///
    /// - Parameters:
    ///   - error: The error to translate.
    ///   - responseHeaders: Optional HTTP headers from the server response.
    /// - Returns: A `NetworkError` representing the error.
    func handle(_ error: Error, responseHeaders: [String: String]?) -> NetworkError

    /// Creates appropriate NetworkError for HTTP status codes.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - data: Optional response data for context.
    ///   - headers: Optional HTTP response headers to attach to the error.
    ///              Callers can read them via `NetworkError.responseHeaders`.
    /// - Returns: A NetworkError for the status code.
    func errorForStatusCode(_ statusCode: Int, data: Data?, headers: [String: String]?) -> NetworkError

    /// Handles decoding errors and translates them to NetworkError.
    ///
    /// - Parameter error: The decoding error to handle.
    /// - Returns: A NetworkError with detailed context.
    func handleDecodingError(_ error: Error) -> NetworkError
}

// MARK: - Backward-compatible defaults

public extension NetworkErrorHandler {
    /// Convenience overload — translates an error without response headers.
    func handle(_ error: Error) -> NetworkError {
        handle(error, responseHeaders: nil)
    }

    /// Convenience overload that forwards to `errorForStatusCode(_:data:headers:)` with no headers.
    func errorForStatusCode(_ statusCode: Int, data: Data?) -> NetworkError {
        errorForStatusCode(statusCode, data: data, headers: nil)
    }
}
