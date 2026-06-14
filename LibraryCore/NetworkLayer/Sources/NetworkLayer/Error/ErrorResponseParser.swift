//
//  ErrorResponseParser.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 24/2/2026.
//


import Foundation

// MARK: - Protocol

/// Extracts a human-readable error message from raw HTTP error-response data.
///
/// Implement this protocol to match your backend's error envelope shape, then
/// pass it to `NetworkServiceBuilder`:
///
/// ```swift
/// struct MyErrorParser: ErrorResponseParser {
///     private struct Body: Decodable {
///         let code: String?
///         let userMessage: String?
///     }
///
///     func extractMessage(from data: Data) -> String? {
///         try? JSONDecoder().decode(Body.self, from: data).userMessage
///     }
/// }
///
/// let service = NetworkServiceBuilder(configuration: config)
///     .withErrorResponseParser(MyErrorParser())
///     .build()
/// ```
public protocol ErrorResponseParser {
    /// Parses raw response body data and returns a user-facing error message,
    /// or `nil` if no message can be extracted.
    func extractMessage(from data: Data) -> String?
}

// MARK: - Default Implementation

/// Default `ErrorResponseParser` that covers common error envelope shapes and
/// falls back to plain UTF-8 text for small, non-HTML responses.
///
/// Recognised JSON keys (first non-nil value wins):
/// - `"error"`
/// - `"message"`
/// - `"errorMessage"`
/// - `"details"`
public struct DefaultErrorResponseParser: ErrorResponseParser {

    public init() {}

    public func extractMessage(from data: Data) -> String? {
        struct ErrorBody: Decodable {
            let error: String?
            let message: String?
            let errorMessage: String?
            let details: String?
        }

        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
            let message = body.error ?? body.message ?? body.errorMessage ?? body.details
            if message != nil { return message }
        }

        // Plain-text fallback for small, non-HTML bodies
        if data.count < 1000,
           let string = String(data: data, encoding: .utf8),
           !string.isEmpty,
           !string.contains("<html") {
            return string
        }

        return nil
    }
}
