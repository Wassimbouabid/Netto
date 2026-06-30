//
//  NetworkingContainer.swift
//

import Foundation

// MARK: - Public Singleton Cache

/// Convenience singleton that holds pre-built network services for apps that
/// prefer a single, globally accessible instance.
///
/// ## Bootstrapping
///
/// Configure once at app startup (e.g. in `AppDelegate` or the `@main` struct)
/// **before** any network request is made:
///
/// ```swift
/// let config = NetworkConfiguration(baseURL: URL(string: "https://api.example.com")!)
///
/// NetworkContainer.shared.configure(
///     using: NetworkServiceBuilder(configuration: config)
///         .withTokenRefreshProvider(MyTokenRefreshProvider())
/// )
///
/// // Optional – only if your app downloads media
/// NetworkContainer.shared.configureMedia(
///     using: MediaServiceBuilder(configuration: config)
/// )
/// ```
///
/// ## Accessing services
///
/// ```swift
/// let service      = NetworkContainer.shared.getNetworkService()
/// let mediaService = NetworkContainer.shared.getMediaService()
/// ```
///
/// ## App-level DI integration
///
/// If you use a separate DI container in the app, forward the result rather
/// than calling `getNetworkService()` at every call site:
///
/// ```swift
/// // Example with Factory
/// Container.shared.networkService.register {
///     NetworkContainer.shared.getNetworkService()
/// }
/// ```
public final class NetworkContainer {

    // MARK: - Shared Instance

    public static let shared = NetworkContainer()
    private init() {}

    // MARK: - Thread Safety

    private let lock = NSLock()

    /// Executes `body` while holding the lock; `defer` guarantees unlock even on throw.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: - Stored State (always accessed through withLock)

    private var _networkService: (any NetworkService)?
    private var _networkConfiguration: NetworkConfiguration?

    private var _mediaService: (any MediaDownloadService)?
    private var _mediaConfiguration: NetworkConfiguration?

    // MARK: - Configuration

    /// Builds and caches the `NetworkService` produced by `builder`.
    ///
    /// Calling this again replaces the cached instance.
    /// Thread-safe — may be called from any queue.
    public func configure(using builder: NetworkServiceBuilder) {
        let service = builder.build()
        withLock {
            _networkConfiguration = builder.configuration
            _networkService       = service
        }
    }

    /// Builds and caches the `MediaDownloadService` produced by `builder`.
    ///
    /// Calling this again replaces the cached instance.
    /// Thread-safe — may be called from any queue.
    public func configureMedia(using builder: MediaServiceBuilder) {
        let service = builder.build()
        withLock {
            _mediaConfiguration = builder.configuration
            _mediaService       = service
        }
    }

    // MARK: - Configuration Access

    /// The `NetworkConfiguration` registered with `configure(using:)`.
    ///
    /// - Precondition: `configure(using:)` must have been called beforehand.
    public var networkConfiguration: NetworkConfiguration {
        withLock {
            guard let config = _networkConfiguration else {
                preconditionFailure(
                    "[NetworkLayer] NetworkConfiguration is not available. " +
                    "Call NetworkContainer.shared.configure(using: NetworkServiceBuilder(configuration: ...)) " +
                    "before accessing networkConfiguration."
                )
            }
            return config
        }
    }

    /// The `NetworkConfiguration` registered with `configureMedia(using:)`.
    ///
    /// - Precondition: `configureMedia(using:)` must have been called beforehand.
    public var mediaConfiguration: NetworkConfiguration {
        withLock {
            guard let config = _mediaConfiguration else {
                preconditionFailure(
                    "[NetworkLayer] Media NetworkConfiguration is not available. " +
                    "Call NetworkContainer.shared.configureMedia(using: MediaServiceBuilder(configuration: ...)) " +
                    "before accessing mediaConfiguration."
                )
            }
            return config
        }
    }

    // MARK: - Service Access

    /// Returns the cached `NetworkService`.
    ///
    /// - Precondition: `configure(using:)` must have been called beforehand.
    public func getNetworkService() -> any NetworkService {
        withLock {
            guard let service = _networkService else {
                preconditionFailure(
                    "[NetworkLayer] NetworkService is not configured. " +
                    "Call NetworkContainer.shared.configure(using: NetworkServiceBuilder(configuration: ...)) " +
                    "before making any network requests."
                )
            }
            return service
        }
    }

    /// Returns the cached `MediaDownloadService`.
    ///
    /// - Precondition: `configureMedia(using:)` must have been called beforehand.
    public func getMediaService() -> any MediaDownloadService {
        withLock {
            guard let service = _mediaService else {
                preconditionFailure(
                    "[NetworkLayer] MediaDownloadService is not configured. " +
                    "Call NetworkContainer.shared.configureMedia(using: MediaServiceBuilder(configuration: ...)) " +
                    "before downloading media."
                )
            }
            return service
        }
    }
}
