//
//  PreRequestHandlerImpl.swift
//

import Foundation

actor PreRequestHandlerImpl: PreRequestHandler {

    // MARK: - Dependencies

    private let tokenStorage: any TokenStorage
    private let refreshProvider: (any TokenRefreshProvider)?

    // MARK: - State

    /// Serialises concurrent token-refresh attempts so only one network call is ever made.
    private var refreshState: RefreshState = .none

    // MARK: - Initialisation

    init(tokenStorage: any TokenStorage, refreshProvider: (any TokenRefreshProvider)?) {
        self.tokenStorage    = tokenStorage
        self.refreshProvider = refreshProvider
    }

    // MARK: - PreRequestHandler

    func prepare(_ request: inout APIRequest) async throws {
        let accessToken = try await fetchValidAccessToken()

        var headers = request.headers ?? [:]

        if headers["Accept"] == nil {
            headers["Accept"] = "application/json"
        }

        headers["Authorization"] = "Bearer \(accessToken)"
        request.headers = headers
    }

    // MARK: - Token Management

    private func fetchValidAccessToken() async throws -> String {
        guard let currentToken = tokenStorage.accessToken else {
            throw NetworkError.authenticationRequired(message: "No access token available", headers: nil)
        }

        if !tokenStorage.isTokenExpired {
            return currentToken
        }

        return try await coordinateTokenRefresh()
    }

    /// Ensures only one refresh request is in flight regardless of concurrent callers.
    private func coordinateTokenRefresh() async throws -> String {
        switch refreshState {
        case .refreshing(let existingTask):
            return try await existingTask.value

        case .none:
            let task = Task<String, Error> { [weak self] in
                guard let self else {
                    throw NetworkError.authenticationRequired(message: "Handler deallocated during refresh", headers: nil)
                }
                do {
                    let token = try await self.performTokenRefresh()
                    await self.transitionToIdle()
                    return token
                } catch {
                    await self.transitionToIdle()
                    throw error
                }
            }
            refreshState = .refreshing(task)
            return try await task.value
        }
    }

    /// Delegates the actual refresh call to the app-supplied `TokenRefreshProvider`,
    /// then persists the new tokens in `TokenStorage`.
    private func performTokenRefresh() async throws -> String {
        guard let provider = refreshProvider else {
            throw NetworkError.authenticationRequired(
                message: "Token refresh required but no TokenRefreshProvider is registered. " +
                "Call NetworkContainer.shared.setTokenRefreshProvider(_:) at app startup.", headers: nil
            )
        }

        let result = try await provider.refreshTokens()

        try tokenStorage.saveTokens(
            accessToken:  result.accessToken,
            refreshToken: result.refreshToken,
            expiresAt:    result.expiresAt
        )

        guard let newToken = tokenStorage.accessToken else {
            throw NetworkError.authenticationRequired(
                message: "Token refresh succeeded but token is unavailable from storage", headers: nil
            )
        }

        return newToken
    }

    private func transitionToIdle() {
        refreshState = .none
    }
}

// MARK: - Supporting Types

private extension PreRequestHandlerImpl {

    /// State machine for deduplicating concurrent refresh requests.
    ///
    /// ```
    /// ┌──────┐  start refresh  ┌────────────┐
    /// │ none │────────────────▶│ refreshing │
    /// └──────┘                 └────────────┘
    ///    ▲                            │
    ///    │      complete/error        │
    ///    └────────────────────────────┘
    /// ```
    enum RefreshState {
        case none
        case refreshing(Task<String, Error>)
    }
}
