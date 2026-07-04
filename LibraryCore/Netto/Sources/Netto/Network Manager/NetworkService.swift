//
//  NetworkService.swift
//

import Foundation

/// `NetworkService` defines the contract for executing network requests asynchronously.
/// Consumers depend on this protocol — never on the concrete implementation.
public protocol NetworkService {

    /// Executes an API request and returns a decoded response body.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint (path, method, parameters, headers, etc.).
    ///   - responseType: The `Decodable` type to decode the response into.
    /// - Returns: A decoded instance of `responseType`.
    /// - Throws: `NetworkError` on connectivity, HTTP, or decoding failures.
    func request<T: Decodable>(_ endpoint: any APIEndpoint, responseType: T.Type) async throws -> T

    /// Executes an API request and returns the decoded body **together with**
    /// the HTTP response headers and status code.
    ///
    /// Use this variant when you need server-side metadata alongside the payload,
    /// such as pagination cursors, rate-limit counters, or ETags:
    ///
    /// ```swift
    /// let response = try await service.requestWithResponse(
    ///     MyEndpoint.list, responseType: Page<Item>.self
    /// )
    /// let nextCursor = response.headers["X-Next-Cursor"]
    /// let items      = response.body.items
    /// ```
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint to request.
    ///   - responseType: The `Decodable` type to decode the body into.
    /// - Returns: A `NetworkResponse<T>` containing the body, headers, and status code.
    /// - Throws: `NetworkError` on connectivity, HTTP, or decoding failures.
    func requestWithResponse<T: Decodable>(_ endpoint: any APIEndpoint, responseType: T.Type) async throws -> NetworkResponse<T>

    /// Performs a network request without expecting a response body (e.g., DELETE / 204 No Content).
    ///
    /// - Parameter endpoint: The API endpoint to request.
    /// - Throws: `NetworkError` if the request fails.
    func requestWithoutResponse(_ endpoint: any APIEndpoint) async throws

    /// Cancels all ongoing network requests.
    func cancelAllRequests()
}
