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
