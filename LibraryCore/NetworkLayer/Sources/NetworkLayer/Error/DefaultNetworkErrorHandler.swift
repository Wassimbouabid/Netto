//
//  DefaultNetworkErrorHandler.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 26/12/2025.
//

internal import Alamofire
import Foundation

/// Default implementation of the `NetworkErrorHandler` protocol.
///
/// This class translates low-level networking errors into application-specific
/// `NetworkError` types, providing consistent error handling across the app.
///
/// The strategy for parsing error bodies is delegated to an `ErrorResponseParser`,
/// which can be replaced to match any backend's error envelope shape.
final class DefaultNetworkErrorHandler: NetworkErrorHandler {

    private let errorResponseParser: any ErrorResponseParser

    init(errorResponseParser: any ErrorResponseParser = DefaultErrorResponseParser()) {
        self.errorResponseParser = errorResponseParser
    }

    func handle(_ error: Error, responseHeaders: [String: String]?) -> NetworkError {
        // Already a NetworkError — headers were embedded at construction time (e.g. by
        // DefaultResponseHandler.validate → errorForStatusCode). Return it unchanged.
        if let networkError = error as? NetworkError {
            return networkError
        }

        // Alamofire error — thread the captured headers through so that
        // responseValidationFailed can attach them to the resulting NetworkError.
        if let afError = error as? AFError {
            return handleAFError(afError, responseHeaders: responseHeaders)
        }

        // URLError / NSURLError — no HTTP response headers available for these.
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }

        if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
            return handleNSURLError(nsError.code)
        }

        return .unknown(underlying: error)
    }

    func errorForStatusCode(_ statusCode: Int, data: Data?, headers: [String: String]?) -> NetworkError {
        let errorMessage = data.flatMap { extractErrorMessage(from: $0) }

        switch statusCode {
        case 400:
            return .badRequest(message: errorMessage, code: nil, headers: headers)
        case 401:
            return .authenticationRequired(message: errorMessage, headers: headers)
        case 403:
            return .forbidden(message: errorMessage, headers: headers)
        case 404:
            return .notFound
        case 405:
            return .methodNotAllowed
        case 408:
            return .timeout
        case 500...599:
            return .serverError(statusCode: statusCode, message: errorMessage, headers: headers)
        default:
            return .serverError(
                statusCode: statusCode,
                message: errorMessage ?? "Unexpected status code (\(statusCode))",
                headers: headers
            )
        }
    }

    func handleDecodingError(_ error: Error) -> NetworkError {
        if let decodingError = error as? DecodingError {
            // extract helpful information from decoding errors
            let errorMessage: String

            switch decodingError {
            case .keyNotFound(let key, let context):
                errorMessage = "Missing key '\(key.stringValue)': \(context.debugDescription)"

            case .typeMismatch(let type, let context):
                errorMessage = "Type '\(type)' mismatch: \(context.debugDescription)"

            case .valueNotFound(let type, let context):
                errorMessage = "Null value found for '\(type)': \(context.debugDescription)"

            case .dataCorrupted(let context):
                errorMessage = "Data corrupted: \(context.debugDescription)"

            @unknown default:
                errorMessage = decodingError.localizedDescription
            }

            return .decodingError(errorMessage)
        } else {
            return .decodingError("Unknown decoding error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Private Helpers

private extension DefaultNetworkErrorHandler {
    func handleAFError(_ error: AFError, responseHeaders: [String: String]?) -> NetworkError {
        // handle underlying URL errors first
        if let urlError = error.underlyingError as? URLError {
            return handleURLError(urlError)
        }

        switch error {
        case .responseValidationFailed(let reason):
            if case .unacceptableStatusCode(let code) = reason {
                return errorForStatusCode(code, data: nil, headers: responseHeaders)
            }
            return .invalidResponse

        case .responseSerializationFailed:
            return .decodingError("Failed to deserialize response")

        case .sessionTaskFailed(let error):
            if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
                return handleNSURLError(nsError.code)
            }
            return .unknown(underlying: error)

        case .createUploadableFailed, .createURLRequestFailed, .multipartEncodingFailed,
             .parameterEncodingFailed:
            return .invalidData

        case .urlRequestValidationFailed:
            return .invalidURL

        case .serverTrustEvaluationFailed:
            return .sslError

        default:
            return .unknown(underlying: error)
        }
    }

    func handleURLError(_ error: URLError) -> NetworkError {
        return handleNSURLError(error.code.rawValue)
    }

    func handleNSURLError(_ code: Int) -> NetworkError {
        switch code {
        case NSURLErrorNotConnectedToInternet:
            return .noInternet
        case NSURLErrorTimedOut:
            return .timeout
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .hostNotFound
        case NSURLErrorCannotConnectToHost:
            return .serverUnreachable
        case NSURLErrorNetworkConnectionLost:
            return .networkConnectionLost
        case NSURLErrorCancelled:
            return .requestCancelled
        case NSURLErrorBadURL, NSURLErrorUnsupportedURL:
            return .invalidURL
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateNotYetValid, NSURLErrorServerCertificateUntrusted:
            return .sslError
        default:
            return .unknown(underlying: NSError(domain: NSURLErrorDomain, code: code))
        }
    }

    func extractErrorMessage(from data: Data) -> String? {
        errorResponseParser.extractMessage(from: data)
    }
}
