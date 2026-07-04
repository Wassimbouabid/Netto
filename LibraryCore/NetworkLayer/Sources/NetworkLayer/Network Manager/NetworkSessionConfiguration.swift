//
//  NetworkSessionConfiguration.swift
//

import Foundation
import Security
internal import Alamofire

// MARK: - NetworkConfiguration

/// All tuneable parameters for the network layer.
///
/// Create one instance at app startup and register it with `NetworkContainer`:
///
/// ```swift
/// NetworkContainer.shared.configure(using: NetworkServiceBuilder(
///     configuration: NetworkConfiguration(
///     baseURL: URL(string: "https://api.example.com")!
/// ))
/// ```
// SecCertificate is an immutable CFType — @unchecked Sendable is safe here.
public struct NetworkConfiguration: @unchecked Sendable {

    /// The root URL that is prepended to every `APIEndpoint.path`.
    public let baseURL: URL

    /// Per-request timeout (resets on each chunk of received data). Default: 30 s.
    public let requestTimeout: TimeInterval

    /// Absolute upper bound for an entire operation. Default: 5 min.
    public let resourceTimeout: TimeInterval

    /// Maximum simultaneous connections to a single host. Default: 5.
    public let maxConnectionsPerHost: Int

    /// Extra HTTP headers appended to every request (e.g. API-key, app version).
    public let additionalHeaders: [String: String]

    /// DER-encoded certificate to pin for SSL validation. Requires `pinnedHost`.
    public let pinnedCertificate: SecCertificate?

    /// The hostname that must present `pinnedCertificate` (e.g. `"api.example.com"`).
    /// Non-pinned hosts continue to use the system's default trust evaluation.
    public let pinnedHost: String?

    public init(
        baseURL: URL,
        requestTimeout: TimeInterval = NetworkTimeouts.standard,
        resourceTimeout: TimeInterval = NetworkTimeouts.resource,
        maxConnectionsPerHost: Int = 5,
        additionalHeaders: [String: String] = [:],
        pinnedCertificate: SecCertificate? = nil,
        pinnedHost: String? = nil
    ) {
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.maxConnectionsPerHost = maxConnectionsPerHost
        self.additionalHeaders = additionalHeaders
        self.pinnedCertificate = pinnedCertificate
        self.pinnedHost = pinnedHost
    }
}

// MARK: - Session Factory

/// Builds configured `Alamofire.Session` instances from a `NetworkConfiguration`.
final class NetworkSessionConfiguration {

    /// Creates an Alamofire session from the supplied configuration.
    static func createSession(with config: NetworkConfiguration) -> Session {
        let urlSessionConfig = URLSessionConfiguration.default

        urlSessionConfig.timeoutIntervalForRequest  = config.requestTimeout
        urlSessionConfig.timeoutIntervalForResource = config.resourceTimeout
        urlSessionConfig.waitsForConnectivity       = false
        urlSessionConfig.allowsCellularAccess       = true
        urlSessionConfig.httpMaximumConnectionsPerHost = config.maxConnectionsPerHost

        var headers: [String: String] = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        config.additionalHeaders.forEach { headers[$0.key] = $0.value }
        urlSessionConfig.httpAdditionalHeaders = headers

        let trustManager: ServerTrustManager? = {
            guard let certificate = config.pinnedCertificate,
                  let host = config.pinnedHost else { return nil }
            let evaluator = PinnedCertificatesTrustEvaluator(certificates: [certificate])
            // allHostsMustBeEvaluated: false — unpinned hosts use system trust evaluation.
            return ServerTrustManager(allHostsMustBeEvaluated: false, evaluators: [host: evaluator])
        }()

        return Session(configuration: urlSessionConfig, serverTrustManager: trustManager)
    }
}
