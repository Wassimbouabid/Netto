//
//  TokenStorage.swift
//

import Foundation

/// Defines the contract for persisting and retrieving authentication tokens.
///
/// Implement this protocol to provide a custom storage backend (e.g. an in-memory
/// store for tests) and register it via `NetworkServiceBuilder.withTokenStorage(_:)`.
public protocol TokenStorage {

    /// The current access token, or `nil` if none is stored.
    var accessToken: String? { get }

    /// The current refresh token, or `nil` if none is stored.
    var refreshToken: String? { get }

    /// The expiration date of the access token, or `nil` if unknown.
    var tokenExpiration: Date? { get }

    /// `true` when the access token is absent or past its expiration date.
    var isTokenExpired: Bool { get }

    /// Persists new tokens to secure storage.
    ///
    /// - Throws: Any error that prevents the tokens from being saved (e.g. a
    ///   Keychain write failure). Callers should treat a thrown error as a sign
    ///   that the session is untrusted and trigger re-authentication.
    func saveTokens(accessToken: String, refreshToken: String, expiresAt: Date?) throws

    /// Removes all stored tokens (e.g. on logout).
    func clearTokens()
}
