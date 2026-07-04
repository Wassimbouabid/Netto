//
//  PreRequestHandler.swift
//

import Foundation

// MARK: - Token Refresh Contract

/// The result returned by a successful token-refresh operation.
public struct TokenRefreshResult: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date?

    public init(accessToken: String, refreshToken: String, expiresAt: Date?) {
        self.accessToken  = accessToken
        self.refreshToken = refreshToken
        self.expiresAt    = expiresAt
    }
}

/// Performs a token-refresh network call on behalf of the library.
///
/// Implement this protocol in the consuming app and register it at startup:
///
/// ```swift
/// NetworkServiceBuilder(configuration: config)
///     .withTokenRefreshProvider(MyRefreshProvider())
///     .build()
/// ```
///
/// The implementation is responsible for calling the auth server.
/// Use a dedicated `URLSession` (or a `NetworkService` instance configured
/// with `skipsPreRequestHandler: true`) to avoid recursive refresh loops.
public protocol TokenRefreshProvider: Sendable {
    func refreshTokens() async throws -> TokenRefreshResult
}

// MARK: - PreRequestHandler

/// Coordinates access-token validation and automatic refresh before every request.
///
/// Actor isolation guarantees that only one refresh operation runs at a time
/// even when many concurrent requests detect an expired token simultaneously.
///
/// ## Refresh Flow
/// ```
/// ┌─────────────────────┐
/// │ Request needs token │
/// └──────────┬──────────┘
///            │
///            ▼
/// ┌─────────────────────┐      ┌──────────────────┐
/// │ Token valid?        │─Yes──▶│ Return token     │
/// └──────────┬──────────┘      └──────────────────┘
///            │ No
///            ▼
/// ┌─────────────────────┐      ┌──────────────────┐
/// │ Refresh in progress?│─Yes──▶│ Await existing   │
/// └──────────┬──────────┘      └──────────────────┘
///            │ No
///            ▼
/// ┌─────────────────────┐
/// │ Delegate to         │
/// │ TokenRefreshProvider│
/// └─────────────────────┘
/// ```
protocol PreRequestHandler {
    func prepare(_ request: inout APIRequest) async throws
}
