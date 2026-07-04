//
//  TestDoubles.swift
//  NetworkLayerTests
//

import Foundation
@testable import NetworkLayer

// MARK: - InMemoryTokenStorage

/// Thread-safe in-memory `TokenStorage` for tests — no Keychain involved.
final class InMemoryTokenStorage: TokenStorage, @unchecked Sendable {

    private let lock = NSLock()

    private var _accessToken: String?
    private var _refreshToken: String?
    private var _expiration: Date?

    private(set) var saveCallCount = 0

    init(accessToken: String? = nil, refreshToken: String? = nil, expiresAt: Date? = nil) {
        _accessToken  = accessToken
        _refreshToken = refreshToken
        _expiration   = expiresAt
    }

    var accessToken: String? {
        lock.lock(); defer { lock.unlock() }
        return _accessToken
    }

    var refreshToken: String? {
        lock.lock(); defer { lock.unlock() }
        return _refreshToken
    }

    var tokenExpiration: Date? {
        lock.lock(); defer { lock.unlock() }
        return _expiration
    }

    var isTokenExpired: Bool {
        lock.lock(); defer { lock.unlock() }
        guard let expiration = _expiration else { return true }
        return Date() > expiration
    }

    func saveTokens(accessToken: String, refreshToken: String, expiresAt: Date?) throws {
        lock.lock(); defer { lock.unlock() }
        _accessToken  = accessToken
        _refreshToken = refreshToken
        _expiration   = expiresAt
        saveCallCount += 1
    }

    func clearTokens() {
        lock.lock(); defer { lock.unlock() }
        _accessToken  = nil
        _refreshToken = nil
        _expiration   = nil
    }
}

// MARK: - CountingRefreshProvider

/// `TokenRefreshProvider` that counts calls, optionally sleeps to widen race
/// windows, and can fail a configurable number of times before succeeding.
final class CountingRefreshProvider: TokenRefreshProvider, @unchecked Sendable {

    struct RefreshFailed: Error {}

    private let lock = NSLock()
    private var _callCount = 0
    private var remainingFailures: Int

    private let delayNanoseconds: UInt64
    private let result: TokenRefreshResult

    init(
        result: TokenRefreshResult = TokenRefreshResult(
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresAt: Date().addingTimeInterval(3600)
        ),
        failuresBeforeSuccess: Int = 0,
        delayNanoseconds: UInt64 = 0
    ) {
        self.result            = result
        self.remainingFailures = failuresBeforeSuccess
        self.delayNanoseconds  = delayNanoseconds
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    /// Synchronous so the lock is never held across a suspension point.
    private func recordCall() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        _callCount += 1
        guard remainingFailures > 0 else { return false }
        remainingFailures -= 1
        return true
    }

    func refreshTokens() async throws -> TokenRefreshResult {
        let shouldFail = recordCall()

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if shouldFail { throw RefreshFailed() }
        return result
    }
}

// MARK: - HTTPURLResponse factory

func makeHTTPResponse(
    statusCode: Int,
    headers: [String: String]? = nil,
    url: String = "https://api.example.com/test"
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headers
    )!
}
