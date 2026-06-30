//
//  MediaServiceBuilder.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 23/2/2026.
//

import Foundation

/// Fluent builder that constructs a `MediaDownloadService`.
///
/// ## Basic (no auth)
///
/// ```swift
/// let mediaService = MediaServiceBuilder(configuration: config)
///     .build()
/// ```
///
/// ## With pre-request auth (same token pipeline as the main network layer)
///
/// Enable when your media URLs are protected behind the same auth scheme
/// as your API (e.g. signed CDN URLs that require an `Authorization` header):
///
/// ```swift
/// let mediaService = MediaServiceBuilder(configuration: config)
///     .withTokenRefreshProvider(MyRefresher())   // required for auth
///     .withTokenStorage(MyCustomStorage())        // optional, defaults to KeychainTokenStorage
///     .build()
/// ```
///
/// The builder accepts the same `NetworkConfiguration` used for the main
/// network layer, so SSL-pinning and timeout settings are shared automatically.
///
/// Each call to `build()` returns a **new, independent** instance.
public final class MediaServiceBuilder {

    // MARK: - Required

    let configuration: NetworkConfiguration

    // MARK: - Optional overrides

    private var tokenRefreshProvider: (any TokenRefreshProvider)?
    private var tokenStorage: (any TokenStorage)?

    // MARK: - Initialisation

    /// Creates a builder with the mandatory base configuration.
    ///
    /// - Parameter configuration: Base URL, timeouts, and optional SSL pinning.
    ///   Typically the same `NetworkConfiguration` used for `NetworkServiceBuilder`.
    public init(configuration: NetworkConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Fluent overrides

    /// Enables pre-request auth handling by registering a token-refresh provider.
    ///
    /// When set, every download request will pass through `PreRequestHandler`,
    /// which validates the access token and refreshes it if expired before
    /// attaching an `Authorization: Bearer …` header to the download.
    ///
    /// Required if your media URLs are behind the same auth scheme as your API.
    @discardableResult
    public func withTokenRefreshProvider(_ provider: any TokenRefreshProvider) -> Self {
        tokenRefreshProvider = provider
        return self
    }

    /// Replaces the default `KeychainTokenStorage` with a custom implementation.
    ///
    /// Only relevant when pre-request auth is enabled via `withTokenRefreshProvider(_:)`.
    @discardableResult
    public func withTokenStorage(_ storage: any TokenStorage) -> Self {
        tokenStorage = storage
        return self
    }

    // MARK: - Terminal operation

    /// Builds and returns a fully-wired `MediaDownloadService`.
    ///
    /// Pre-request handling is **enabled** when `withTokenRefreshProvider(_:)` has
    /// been called; otherwise downloads are made without auth headers.
    ///
    /// Each call produces an independent instance — no shared state is mutated.
    public func build() -> any MediaDownloadService {
        let preRequestHandler: (any PreRequestHandler)? = tokenRefreshProvider != nil || tokenStorage != nil
            ? PreRequestHandlerImpl(
                tokenStorage:    tokenStorage ?? KeychainTokenStorage.shared,
                refreshProvider: tokenRefreshProvider
              )
            : nil

        return MediaDownloadServiceImpl(
            configuration:     configuration,
            preRequestHandler: preRequestHandler
        )
    }
}
