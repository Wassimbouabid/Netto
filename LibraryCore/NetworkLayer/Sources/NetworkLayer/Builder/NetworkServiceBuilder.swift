//
//  NetworkServiceBuilder.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 23/2/2026.
//

import Foundation

/// Fluent builder that wires the full `NetworkService` dependency graph.
///
/// Required parameters are enforced at **initialisation time**; every other
/// dependency has a sensible default and can be overridden with a `with…()`
/// call before `build()` is invoked.
///
/// ```swift
/// let service = NetworkServiceBuilder(configuration: config)
///     .withTokenRefreshProvider(MyRefresher())
///     .withTokenStorage(MyStorage())     // optional – defaults to KeychainTokenStorage
///     .loggingEnabled(false)             // optional – defaults to true
///     .build()
/// ```
///
/// Each call to `build()` produces a **new, independent** `NetworkService`
/// instance, so you can safely create multiple services (e.g. one per test).
public final class NetworkServiceBuilder {

    // MARK: - Required

    let configuration: NetworkConfiguration

    // MARK: - Optional overrides

    private var tokenRefreshProvider: (any TokenRefreshProvider)?
    private var tokenStorage: (any TokenStorage)?
    private var networkMonitor: (any NetworkMonitor)?
    private var errorResponseParser: (any ErrorResponseParser)?
    private var customErrorHandler: (any NetworkErrorHandler)?
    private var customResponseHandler: (any ResponseHandler)?
    private var customLogger: (any NetworkLogger)?
    private var connectivityListener: (any ConnectivityListener)?
    private var customDecoder: JSONDecoder?
    private var enableLogging: Bool = true
    private var redactSensitiveData: Bool = true

    // MARK: - Initialisation

    /// Creates a builder with the mandatory base configuration.
    ///
    /// - Parameter configuration: Base URL, timeouts, extra headers, and optional SSL pinning.
    public init(configuration: NetworkConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Fluent overrides

    /// Registers the provider that performs token-refresh calls.
    /// Required for endpoints that need authentication.
    @discardableResult
    public func withTokenRefreshProvider(_ provider: any TokenRefreshProvider) -> Self {
        tokenRefreshProvider = provider
        return self
    }

    /// Replaces the default `KeychainTokenStorage` with a custom implementation.
    @discardableResult
    public func withTokenStorage(_ storage: any TokenStorage) -> Self {
        tokenStorage = storage
        return self
    }

    /// Replaces the default `DefaultNetworkMonitor` with a custom implementation.
    @discardableResult
    public func withNetworkMonitor(_ monitor: any NetworkMonitor) -> Self {
        networkMonitor = monitor
        return self
    }

    /// Replaces the default `DefaultErrorResponseParser` with a custom implementation.
    ///
    /// Use this to match your backend's error envelope shape:
    /// ```swift
    /// struct MyErrorParser: ErrorResponseParser {
    ///     func extractMessage(from data: Data) -> String? {
    ///         try? JSONDecoder().decode(MyErrorBody.self, from: data).userMessage
    ///     }
    /// }
    ///
    /// NetworkServiceBuilder(configuration: config)
    ///     .withErrorResponseParser(MyErrorParser())
    ///     .build()
    /// ```
    @discardableResult
    public func withErrorResponseParser(_ parser: any ErrorResponseParser) -> Self {
        errorResponseParser = parser
        return self
    }

    /// Replaces the default `DefaultNetworkErrorHandler` with a custom implementation.
    ///
    /// Use this to apply domain-specific error translation or to wrap the default handler.
    /// - Note: When a custom handler is provided, `withErrorResponseParser(_:)` has no effect
    ///   since the parser is only used by `DefaultNetworkErrorHandler`.
    @discardableResult
    public func withErrorHandler(_ handler: any NetworkErrorHandler) -> Self {
        customErrorHandler = handler
        return self
    }

    /// Replaces the default `DefaultResponseHandler` with a custom implementation.
    ///
    /// Use this to change response validation rules or the JSON decoding strategy.
    @discardableResult
    public func withResponseHandler(_ handler: any ResponseHandler) -> Self {
        customResponseHandler = handler
        return self
    }

    /// Replaces the plain `JSONDecoder` used by the default response handler.
    ///
    /// Use this to set date/key decoding strategies, or to opt in to the
    /// lenient `RobustJSONDecoder` shipped with this library:
    /// ```swift
    /// NetworkServiceBuilder(configuration: config)
    ///     .withDecoder(RobustJSONDecoder())
    ///     .build()
    /// ```
    /// - Note: This has no effect when a custom response handler is supplied
    ///   via `withResponseHandler(_:)`.
    @discardableResult
    public func withDecoder(_ decoder: JSONDecoder) -> Self {
        customDecoder = decoder
        return self
    }

    /// Replaces the default `DefaultNetworkLogger` with a custom implementation.
    ///
    /// Use this to integrate with OSLog, SwiftyBeaver, your analytics pipeline, etc.
    @discardableResult
    public func withLogger(_ logger: any NetworkLogger) -> Self {
        customLogger = logger
        return self
    }

    /// Registers a UI-layer listener that is notified when connectivity changes.
    ///
    /// The listener is held **weakly** — the caller is responsible for keeping
    /// it alive. Both methods are dispatched on the main thread.
    ///
    /// ```swift
    /// NetworkServiceBuilder(configuration: config)
    ///     .withConnectivityListener(myAppCoordinator)
    ///     .build()
    /// ```
    @discardableResult
    public func withConnectivityListener(_ listener: any ConnectivityListener) -> Self {
        connectivityListener = listener
        return self
    }

    /// Enables or disables request / response logging. Defaults to `true`.
    @discardableResult
    public func loggingEnabled(_ enabled: Bool) -> Self {
        enableLogging = enabled
        return self
    }

    /// Enables or disables redaction of sensitive data (headers, parameters, response fields)
    /// in logs produced by the default `NetworkLogger`. Defaults to `true`.
    ///
    /// When enabled, sensitive values are replaced with `****REDACTED****`. Disable only in
    /// trusted debugging environments — never in production builds.
    /// - Note: This has no effect when a custom logger is supplied via `withLogger(_:)`.
    @discardableResult
    public func redactSensitiveDataEnabled(_ enabled: Bool) -> Self {
        redactSensitiveData = enabled
        return self
    }

    // MARK: - Terminal operation

    /// Builds and returns a fully-wired `NetworkService`.
    ///
    /// Each call produces an independent instance — no shared state is mutated.
    public func build() -> any NetworkService {
        let storage      = tokenStorage ?? KeychainTokenStorage.shared
        let monitor      = networkMonitor ?? DefaultNetworkMonitor()
        let errorHandler = customErrorHandler ?? DefaultNetworkErrorHandler(
            errorResponseParser: errorResponseParser ?? DefaultErrorResponseParser()
        )
        let responseHandler   = customResponseHandler ?? DefaultResponseHandler(
            errorHandler: errorHandler,
            decoder: customDecoder ?? JSONDecoder()
        )
        let preRequestHandler = PreRequestHandlerImpl(
            tokenStorage:    storage,
            refreshProvider: tokenRefreshProvider
        )
        let logger  = customLogger ?? DefaultNetworkLogger(includeSensitiveData: !redactSensitiveData)
        let session = NetworkSessionConfiguration.createSession(with: configuration)

        // Wire the UI connectivity listener (weak to avoid retaining the UI layer)
        if let listener = connectivityListener {
            monitor.onConnectivityChanged { [weak listener] isConnected in
                if isConnected {
                    listener?.onConnectionRestored()
                } else {
                    listener?.onConnectionLost()
                }
            }
        }

        return NetworkManager(
            baseURL:             configuration.baseURL,
            session:             session,
            preRequestHandler:   preRequestHandler,
            responseHandler:     responseHandler,
            errorHandler:        errorHandler,
            logger:              logger,
            connectivityMonitor: monitor,
            enableLogging:       enableLogging
        )
    }
}
