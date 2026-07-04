//
//  ResponseHandler.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 26/12/2025.
//
import Foundation

/// Handles the decoding of network responses.
///
/// ResponseHandler is responsible for converting raw response data into model objects.
public protocol ResponseHandler {
    /// Validates an HTTP response.
    ///
    /// - Parameters:
    ///   - data: The response data.
    ///   - response: The HTTP response.
    /// - Throws: NetworkError if the response is invalid.
    func validate(_ data: Data, response: HTTPURLResponse) throws

    /// Decodes response data into the specified type.
    ///
    /// - Parameters:
    ///   - data: The response data to decode.
    ///   - type: The type to decode the data into.
    /// - Returns: A decoded instance of the specified type.
    /// - Throws: `NetworkError.decodingError` if the data cannot be decoded.
    func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T
}
