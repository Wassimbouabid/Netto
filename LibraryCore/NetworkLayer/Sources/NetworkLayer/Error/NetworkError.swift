//
//  NetworkError.swift
//  NetworkLayer
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

// MARK: - LocalizedError

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        // Connection Errors
        case .noInternet:
            return "No internet connection. Please check your network and try again."

        case .timeout:
            return "Connection timed out. Please check your internet connection and try again."

        case .hostNotFound:
            return "Server not found. You can continue working offline, and your changes will sync when the server is back."

        case .serverUnreachable:
            return "Server is currently unavailable. You can continue working offline, and your changes will sync when the server is back."

        case .networkConnectionLost:
            return "Network connection lost. Please check your connection and try again."

        case .sslError:
            return "Secure connection failed. Please try again."

        // Request Errors
        case .invalidURL:
            return "Invalid server address. Please contact support."

        case .invalidData:
            return "Invalid data format. Please try again."

        case .requestCancelled:
            return "Request was cancelled."

        // Response Errors
        case .decodingError(let details):
            return "Failed to process server response: \(details)"

        case .emptyResponse:
            return "Server returned no data. Please try again."

        case .invalidResponse:
            return "Invalid server response. Please try again."

        // HTTP Status Code Errors
        case .badRequest(let message, _, _):
            return message ?? "Invalid request. Please try again."

        case .authenticationRequired(let message, _):
            return message ?? "Authentication required. You can still work offline."

        case .forbidden(let message, _):
            return message ?? "Access denied."

        case .notFound:
            return "Resource not found."

        case .methodNotAllowed:
            return "Operation not allowed."

        case .serverError(let statusCode, let message, _) where statusCode >= 500:
            return message ?? "Server is experiencing issues. You can continue working offline."

        case .serverError(_, let message, _):
            return message ?? "Server error. Please try again."

        // Domain Error
        case .domainError(_, let underlyingError):
            return underlyingError.localizedDescription

        // Unknown
        case .unknown(let underlying):
            return underlying?.localizedDescription ?? "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Error Classification

extension NetworkError {
    /// Returns true for infrastructure errors (HTTP, connectivity)
    public var isInfrastructureError: Bool {
        switch self {
        case .noInternet, .timeout, .hostNotFound, .serverUnreachable, .networkConnectionLost, .sslError,
             .invalidURL, .invalidData, .requestCancelled, .decodingError, .emptyResponse, .invalidResponse,
             .badRequest, .authenticationRequired, .forbidden, .notFound, .methodNotAllowed, .serverError,
             .unknown:
            return true
        case .domainError:
            return false
        }
    }

    /// Returns true if server is down/unreachable
    public var isServerDownError: Bool {
        switch self {
        case .serverUnreachable, .hostNotFound, .timeout:
            return true
        case .serverError(let code, _, _) where code >= 500:
            return true
        default:
            return false
        }
    }

    /// Returns true if user can work offline
    public var supportsOfflineMode: Bool {
        switch self {
        case .noInternet, .serverUnreachable, .hostNotFound, .timeout, .networkConnectionLost:
            return true
        case .serverError(let code, _, _) where code >= 500:
            return true
        default:
            return false
        }
    }
}

// MARK: - Equatable

public extension NetworkError {
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noInternet, .noInternet),
             (.timeout, .timeout),
             (.hostNotFound, .hostNotFound),
             (.serverUnreachable, .serverUnreachable),
             (.networkConnectionLost, .networkConnectionLost),
             (.sslError, .sslError),
             (.invalidURL, .invalidURL),
             (.invalidData, .invalidData),
             (.emptyResponse, .emptyResponse),
             (.invalidResponse, .invalidResponse),
             (.requestCancelled, .requestCancelled),
             (.notFound, .notFound),
             (.methodNotAllowed, .methodNotAllowed):
            return true

        case (.decodingError(let lhsDetails), .decodingError(let rhsDetails)):
            return lhsDetails == rhsDetails

        case (.badRequest(let lhsMsg, let lhsCode, _), .badRequest(let rhsMsg, let rhsCode, _)):
            return lhsMsg == rhsMsg && lhsCode == rhsCode

        case (.authenticationRequired(let lhsMsg, _), .authenticationRequired(let rhsMsg, _)):
            return lhsMsg == rhsMsg

        case (.forbidden(let lhsMsg, _), .forbidden(let rhsMsg, _)):
            return lhsMsg == rhsMsg

        case (.serverError(let lhsCode, let lhsMsg, _), .serverError(let rhsCode, let rhsMsg, _)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg

        case (.domainError(let lhsCtx, _), .domainError(let rhsCtx, _)):
            return lhsCtx == rhsCtx

        case (.unknown, .unknown):
            return true

        default:
            return false
        }
    }
}
