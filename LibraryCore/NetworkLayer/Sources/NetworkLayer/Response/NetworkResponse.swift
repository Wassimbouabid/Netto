//
//  NetworkResponse.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 4/3/2026.
//


import Foundation

/// A decoded network response that includes the response body, HTTP headers,
/// and the status code.
///
/// Returned by `NetworkService.requestWithResponse(_:responseType:)` when the
/// caller needs to inspect server-side metadata alongside the decoded payload:
///
/// ```swift
/// let response = try await networkService.requestWithResponse(
///     MyEndpoint.listItems,
///     responseType: ItemsPage.self
/// )
///
/// let items      = response.body
/// let totalCount = response.headers["X-Total-Count"]
/// let statusCode = response.statusCode   // e.g. 200
/// ```
///
/// Common use-cases:
/// - **Pagination** — reading `Link`, `X-Total-Count`, or `X-Next-Cursor` headers
/// - **Rate limiting** — reading `X-RateLimit-Remaining` / `Retry-After`
/// - **Caching** — reading `ETag` or `Last-Modified` for conditional requests
/// - **Tracing** — reading `X-Request-Id` for error correlation
public struct NetworkResponse<Body: Decodable> {

    /// The decoded response body.
    public let body: Body

    /// HTTP response headers returned by the server.
    ///
    /// Keys follow the casing reported by the server (typically lowercase for
    /// HTTP/2, mixed-case for HTTP/1.1). Use a case-insensitive lookup when
    /// portability across servers matters.
    public let headers: [String: String]

    /// The HTTP status code of the response (e.g. `200`, `201`).
    public let statusCode: Int
}