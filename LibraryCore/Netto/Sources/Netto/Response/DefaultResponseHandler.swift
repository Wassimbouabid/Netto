//
//  DefaultResponseHandler.swift
//  Netto
//
//  Created by Bouabid Wassim on 26/12/2025.
//
import Foundation

/// Default implementation of the `ResponseHandler` protocol.
///
/// This class focuses on decoding responses, delegating error handling to the ErrorHandler.
final class DefaultResponseHandler: ResponseHandler {

    private let errorHandler: any NetworkErrorHandler
    private let decoder: JSONDecoder

    init(errorHandler: any NetworkErrorHandler, decoder: JSONDecoder = JSONDecoder()) {
        self.errorHandler = errorHandler
        self.decoder      = decoder
    }

    func validate(_ data: Data, response: HTTPURLResponse) throws {
        let statusCode = response.statusCode

        // check if status code indicates success (200-299)
        guard (200...299).contains(statusCode) else {
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    acc[key] = value
                }
            }
            throw errorHandler.errorForStatusCode(statusCode, data: data, headers: headers)
        }

        // 204 No Content is valid - empty response is expected
        if statusCode == 204 {
            return
        }

        // For other success codes, check for empty response when content is expected
        if data.isEmpty && response.expectedContentLength > 0 {
            throw NetworkError.emptyResponse
        }
    }

    func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // delegate error handling to the error handler
            throw errorHandler.handleDecodingError(error)
        }
    }
}
