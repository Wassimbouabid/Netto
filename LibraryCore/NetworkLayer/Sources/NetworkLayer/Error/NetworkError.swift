//
//  NetworkError.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 26/12/2025.
//
import Foundation

/// Network-related errors with user-friendly messages
public indirect enum NetworkError: Error, Equatable {
    // Connection Errors
    case noInternet
    case timeout
    case hostNotFound
    case serverUnreachable
    case networkConnectionLost
    case sslError

    // Request Errors
    case invalidURL
    case invalidData
    case requestCancelled

    // Response Errors
    case decodingError(String)
    case emptyResponse
    case invalidResponse

    // HTTP Status Code Errors
    case badRequest(message: String?, code: String?, headers: [String: String]?)
    case authenticationRequired(message: String?, headers: [String: String]?)
    case forbidden(message: String?, headers: [String: String]?)
    case notFound
    case methodNotAllowed
    case serverError(statusCode: Int, message: String?, headers: [String: String]?)

    // Domain-contextualized error
    case domainError(context: ServiceContext, underlyingError: Error)

    // Other Errors
    case unknown(underlying: Error?)

    // MARK: - Status Code

    /// HTTP status code if available
    public var statusCode: Int? {
        switch self {
        case .badRequest: return 400
        case .authenticationRequired: return 401
        case .forbidden: return 403
        case .notFound: return 404
        case .methodNotAllowed: return 405
        case .serverError(let code, _, _): return code
        default:
            return nil
        }
    }

    /// HTTP response headers returned by the server alongside this error, if available.
    ///
    /// Populated for `badRequest`, `authenticationRequired`, `forbidden`, and `serverError`
    /// when a real HTTP response was received. Useful for reading metadata such as:
    /// - `WWW-Authenticate` on a `401 authenticationRequired`
    /// - `Retry-After` on a `429` / `503` `serverError`
    /// - `X-Request-Id` for error correlation
    public var responseHeaders: [String: String]? {
        switch self {
        case .badRequest(_, _, let headers):          return headers
        case .authenticationRequired(_, let headers): return headers
        case .forbidden(_, let headers):              return headers
        case .serverError(_, _, let headers):         return headers
        default:                                      return nil
        }
    }
}
