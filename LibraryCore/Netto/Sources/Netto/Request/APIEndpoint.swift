//
//  APIEndpoint.swift
//

import Foundation

/// Defines the structure of a single API endpoint.
/// Conform to this protocol in the consuming app to describe each request.
public protocol APIEndpoint {
    /// The endpoint path, relative to the base URL configured in `NetworkConfiguration`.
    var path: String { get }

    /// The HTTP method for the request.
    var method: HTTPMethod { get }

    /// Query parameters or request body, depending on the encoding strategy.
    var parameters: [String: Any]? { get }

    /// How parameters are encoded into the request.
    var encoding: ParameterEncoding { get }

    /// Custom per-request headers. Library-level headers (e.g. Auth, Accept) are added automatically.
    var headers: [String: String]? { get }

    /// Set to `true` to bypass the `PreRequestHandler` (e.g. login or token-refresh endpoints).
    var skipsPreRequestHandler: Bool { get }

    /// Optional per-request timeout override.
    ///
    /// `nil` defers to the session-level timeout defined in `NetworkConfiguration`.
    var timeout: TimeInterval? { get }

    /// Optional per-request base URL override.
    ///
    /// When non-`nil`, this URL is used instead of the base URL defined in `NetworkConfiguration`.
    var customBaseURL: URL? { get }
}

public extension APIEndpoint {
    var skipsPreRequestHandler: Bool { false }
    var timeout: TimeInterval? { nil }
    var customBaseURL: URL? { nil }
}
