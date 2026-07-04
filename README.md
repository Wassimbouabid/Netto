# NetworkLayer

A protocol-oriented, dependency-injected networking layer for iOS, built on top of
[Alamofire](https://github.com/Alamofire/Alamofire). It gives your app a clean,
testable API surface for making requests, downloading media, handling auth-token
refresh, monitoring connectivity, and normalising errors — **without ever leaking
Alamofire types into your application code**.

The third-party dependencies are imported with Swift's `internal import`, so
`import NetworkLayer` is all your app ever needs. You depend on protocols
(`NetworkService`, `MediaDownloadService`, …), never on concrete implementations.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Defining endpoints](#defining-endpoints)
- [Making requests](#making-requests)
- [Authentication & token refresh](#authentication--token-refresh)
- [Error handling](#error-handling)
- [Media downloads](#media-downloads)
- [Connectivity monitoring](#connectivity-monitoring)
- [Logging & redaction](#logging--redaction)
- [SSL certificate pinning](#ssl-certificate-pinning)
- [Customisation reference](#customisation-reference)
- [Testing](#testing)
- [Public API surface](#public-api-surface)
- [License](#license)

---

## Features

- **Async/await first** — every request is `async throws`.
- **Protocol-oriented & injectable** — swap any collaborator (logger, error handler,
  response handler, token storage, network monitor) via fluent builders.
- **Typed errors** — a single `NetworkError` enum covering connectivity, HTTP status,
  decoding, and domain-contextualised failures.
- **Automatic token refresh** — actor-isolated `PreRequestHandler` refreshes expired
  access tokens once, even under concurrent requests, and attaches the `Authorization`
  header for you.
- **Keychain-backed token storage** by default, replaceable for tests.
- **Media downloads** with retry and batch support, optionally sharing the same
  auth pipeline as your API.
- **Connectivity monitoring** via `NWPathMonitor`, with a UI bridge for
  no-internet / restored events.
- **Structured logging** with sensitive-data redaction on by default.
- **SSL certificate pinning** per host.
- **No leaked dependencies** — Alamofire and CocoaLumberjack stay internal.

---

## Requirements

| | |
|---|---|
| iOS | 16.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

---

## Dependencies

Declared in [`Package.swift`](Package.swift) and pinned in
[`Package.resolved`](Package.resolved). They are fetched automatically by Swift
Package Manager — you do **not** add them to your app yourself.

| Package | Minimum version | Resolved | Purpose |
|---|---|---|---|
| [Alamofire](https://github.com/Alamofire/Alamofire) | `5.9.0` | `5.11.1` | HTTP session management, request/response handling, multipart uploads, and SSL trust evaluation. Imported `internal` — never exposed to your app. |
| [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) | `3.8.0` | `3.9.0` | Fast, flexible logging backend used by `DefaultNetworkLogger`. Imported `internal`. |
| [swift-log](https://github.com/apple/swift-log) | — | `1.10.1` | Transitive dependency of CocoaLumberjack. Resolved automatically. |

Because both direct dependencies are consumed through `internal import`, none of
their symbols appear in NetworkLayer's public API. Your app links them transitively
but should code exclusively against NetworkLayer's own types.

---

## Installation

NetworkLayer is distributed as a Swift package.

### Xcode (recommended)

1. **File ▸ Add Package Dependencies…**
2. Paste the repository URL:
   ```
   https://github.com/Wassimbouabid/NetworkLayer-iOS.git
   ```
3. Choose the dependency rule (e.g. **Up to Next Major Version** from `1.0.0`).
4. Add the **NetworkLayer** library product to your app target.

Xcode resolves Alamofire, CocoaLumberjack, and swift-log automatically.

### `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/Wassimbouabid/NetworkLayer-iOS.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "NetworkLayer", package: "NetworkLayer-iOS")
        ]
    )
]
```

### Local package (monorepo / development)

If the package lives alongside your app in the same repository:

```swift
dependencies: [
    .package(path: "../NetworkLayer-iOS")
]
```

Or drag the `NetworkLayer-iOS` folder into your Xcode workspace and add the
**NetworkLayer** product to your target.

Then, everywhere you use it:

```swift
import NetworkLayer
```

---

## Architecture

```
LibraryCore/NetworkLayer/Sources/NetworkLayer/
├── NetworkLayer.swift            # Public API surface (documentation + exports)
├── Builder/                      # Fluent builders + app-wide container
│   ├── NetworkServiceBuilder     #   wires and builds a NetworkService
│   ├── MediaServiceBuilder       #   wires and builds a MediaDownloadService
│   └── NetworkingContainer       #   optional singleton cache of built services
├── Network Manager/              # Core request execution
│   ├── NetworkService            #   the protocol your app depends on
│   ├── NetworkManager            #   Alamofire-backed implementation
│   ├── NetworkSessionConfiguration + NetworkConfiguration
│   └── NetworkTimeouts
├── Request/                      # Request modelling
│   ├── APIEndpoint, APIRequest, HTTPMethod, ParameterEncoding, MultipartPart
│   ├── ServiceContext            #   domain tag for contextualised errors
│   └── DomainService             #   error-contextualisation helper
├── Response/                     # Response validation & decoding
│   ├── ResponseHandler / DefaultResponseHandler
│   └── NetworkResponse           #   body + headers + status code
├── Error/                        # Error normalisation
│   ├── NetworkError              #   typed error enum
│   ├── NetworkErrorHandler / DefaultNetworkErrorHandler
│   └── ErrorResponseParser
├── Decoder/                      # RobustJSONDecoder with default-value recovery
├── Logger/                       # NetworkLogger / DefaultNetworkLogger (redaction)
├── PreRequest/                   # Token validation + refresh pipeline
│   ├── PreRequestHandler / PreRequestHandlerImpl
│   └── TokenRefreshProvider / TokenRefreshResult
├── Storage/                      # TokenStorage / KeychainTokenStorage
├── Network Monitor/              # NWPathMonitor connectivity + UI bridge
├── Media/                        # MediaDownloadService and models
└── Utils/                        # Alamofire adapters, Encodable helpers
```

The dependency graph is wired for you by the builders — you interact only with
`NetworkService`, `MediaDownloadService`, and the protocols you choose to implement.

---

## Quick start

Configure the layer **once** at app startup, before making any request.

```swift
import NetworkLayer

@main
struct MyApp: App {
    init() {
        let config = NetworkConfiguration(
            baseURL: URL(string: "https://api.example.com")!,
            additionalHeaders: ["X-App-Version": "1.0.0"]
        )

        NetworkContainer.shared.configure(
            using: NetworkServiceBuilder(configuration: config)
                .withTokenRefreshProvider(AppTokenRefresher())   // if you need auth
        )

        // Optional — only if your app downloads media
        NetworkContainer.shared.configureMedia(
            using: MediaServiceBuilder(configuration: config)
        )
    }

    var body: some Scene { /* … */ }
}
```

Then retrieve services anywhere:

```swift
let service = NetworkContainer.shared.getNetworkService()
```

> `NetworkContainer` is an **optional** convenience. If you already use a DI
> framework (Factory, Swinject, …), call `builder.build()` yourself and register
> the returned `any NetworkService` in your own container instead.

---

## Defining endpoints

Describe each request by conforming to `APIEndpoint`. Only `path` and `method`
are required — everything else has a default.

```swift
enum UserEndpoint: APIEndpoint {
    case profile(id: String)
    case updateName(String)

    var path: String {
        switch self {
        case .profile(let id): return "/users/\(id)"
        case .updateName:      return "/users/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .profile:    return .get
        case .updateName: return .patch
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .profile:              return nil
        case .updateName(let name): return ["name": name]
        }
    }

    var encoding: ParameterEncoding { .json }
    var headers: [String: String]?  { nil }
}
```

Optional overrides available on every endpoint:

- `skipsPreRequestHandler` — set `true` for login / token-refresh endpoints to
  bypass the auth pipeline (default `false`).
- `timeout` — per-request timeout override (default: session timeout).
- `customBaseURL` — hit a different host for this one request.

---

## Making requests

`NetworkService` offers three call styles.

```swift
let service = NetworkContainer.shared.getNetworkService()

// 1. Decode the body directly
let profile = try await service.request(
    UserEndpoint.profile(id: "42"),
    responseType: UserProfile.self
)

// 2. Decode the body AND read response metadata (headers, status code)
let response = try await service.requestWithResponse(
    UserEndpoint.profile(id: "42"),
    responseType: UserProfile.self
)
let etag   = response.headers["ETag"]
let status = response.statusCode      // e.g. 200
let user   = response.body

// 3. No response body expected (e.g. DELETE / 204)
try await service.requestWithoutResponse(UserEndpoint.updateName("New Name"))

// Cancel everything in flight
service.cancelAllRequests()
```

### Multipart uploads

```swift
var encoding: ParameterEncoding {
    .multipart([
        .init(name: "title",  .text("Profile photo")),
        .init(name: "avatar", .data(imageData, mimeType: "image/jpeg", filename: "avatar.jpg")),
        .init(name: "doc",    .fileURL(fileURL, mimeType: "application/pdf")),
    ])
}
```

---

## Authentication & token refresh

The layer manages access-token validation and refresh transparently. Implement
`TokenRefreshProvider` to perform the actual refresh network call, and register
it on the builder.

```swift
struct AppTokenRefresher: TokenRefreshProvider {
    func refreshTokens() async throws -> TokenRefreshResult {
        // Call your auth server here. Use a dedicated URLSession or an endpoint
        // with `skipsPreRequestHandler = true` to avoid recursive refreshes.
        let dto = try await AuthAPI.refresh()
        return TokenRefreshResult(
            accessToken:  dto.accessToken,
            refreshToken: dto.refreshToken,
            expiresAt:    dto.expiresAt
        )
    }
}
```

What you get automatically:

- Tokens are stored in the **Keychain** (`KeychainTokenStorage`) by default.
- Before each authenticated request, the token is validated; if expired, it is
  refreshed **once** even under many concurrent requests (actor-isolated).
- A valid `Authorization: Bearer …` header is attached for you.

Provide a custom store (e.g. in-memory for tests) via
`.withTokenStorage(_:)` — conform to `TokenStorage`.

---

## Error handling

Every failure surfaces as a typed `NetworkError`:

```swift
do {
    let profile = try await service.request(UserEndpoint.profile(id: "42"),
                                            responseType: UserProfile.self)
} catch let error as NetworkError {
    switch error {
    case .noInternet, .networkConnectionLost:
        showOfflineBanner()
    case .authenticationRequired:
        routeToLogin()
    case .serverError(let statusCode, let message, _):
        log("Server \(statusCode): \(message ?? "—")")
    case .decodingError(let details):
        assertionFailure("Contract mismatch: \(details)")
    default:
        showGenericError(error.localizedDescription)
    }
}
```

Useful members:

- `error.statusCode` — HTTP status when applicable (`400`, `401`, `403`, `404`, `405`, or the server code).
- `error.responseHeaders` — headers returned alongside `400/401/403/serverError`
  (read `Retry-After`, `WWW-Authenticate`, `X-Request-Id`, …).
- `NetworkError` conforms to `LocalizedError`, so `localizedDescription` yields a
  user-friendly message.

### Domain-contextualised errors

Conform a service to `DomainService` to tag its failures with a `ServiceContext`
while letting infrastructure errors pass through untouched:

```swift
extension ServiceContext {
    static let userProfile = ServiceContext(rawValue: "userProfile")
}

struct ProfileService: DomainService {
    static let context: ServiceContext = .userProfile
    let network = NetworkContainer.shared.getNetworkService()

    func loadProfile(id: String) async throws -> UserProfile {
        try await withContext {
            try await network.request(UserEndpoint.profile(id: id),
                                      responseType: UserProfile.self)
        }
    }
}
```

Match your backend's error envelope by supplying an `ErrorResponseParser` via
`.withErrorResponseParser(_:)`.

---

## Media downloads

Build a `MediaDownloadService` for downloading binary assets, with optional retry
and batching:

```swift
NetworkContainer.shared.configureMedia(
    using: MediaServiceBuilder(configuration: config)
        .withTokenRefreshProvider(AppTokenRefresher())   // only if media URLs are auth-protected
)

let media = NetworkContainer.shared.getMediaService()

// Single download
let result = await media.downloadMedia(
    MediaDownloadRequest(id: "avatar-42", url: "https://cdn.example.com/a.jpg", maxRetryAttempts: 2)
)
switch result {
case .success(let data): renderImage(data)
case .failure(let error): log(error)
}

// Batch download — results keyed by request
let results = await media.downloadMultipleMedia([req1, req2, req3])
```

When a `TokenRefreshProvider` is registered, media requests flow through the same
pre-request auth pipeline (a `Bearer` header is attached automatically).

---

## Connectivity monitoring

Bridge no-internet / restored events into your UI by conforming to
`ConnectivityListener` and registering it on the builder:

```swift
final class AppCoordinator: ConnectivityListener {
    func onConnectionLost()     { showOfflineBanner() }
    func onConnectionRestored() { hideOfflineBanner() }
}

NetworkServiceBuilder(configuration: config)
    .withConnectivityListener(coordinator)   // held weakly; callbacks on main thread
    .build()
```

Supply a custom monitor via `.withNetworkMonitor(_:)` (conform to `NetworkMonitor`);
the default uses `NWPathMonitor`.

---

## Logging & redaction

`DefaultNetworkLogger` (CocoaLumberjack-backed) logs requests, responses, and
errors. **Sensitive-data redaction is on by default** — headers, parameters, and
response fields that look sensitive are replaced with `****REDACTED****`.

```swift
NetworkServiceBuilder(configuration: config)
    .loggingEnabled(true)                    // default true
    .redactSensitiveDataEnabled(true)        // default true — keep ON in production
    .withLogger(MyOSLogAdapter())            // or plug your own NetworkLogger
    .build()
```

> Only disable redaction in trusted local debugging — never in release builds.
> Providing a custom logger via `.withLogger(_:)` bypasses the built-in redaction.

---

## SSL certificate pinning

Pin a DER-encoded certificate to a specific host through `NetworkConfiguration`.
Non-pinned hosts continue to use the system's default trust evaluation.

```swift
let certData = try Data(contentsOf: Bundle.main.url(forResource: "api", withExtension: "cer")!)
let certificate = SecCertificateCreateWithData(nil, certData as CFData)!

let config = NetworkConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    pinnedCertificate: certificate,
    pinnedHost: "api.example.com"
)
```

---

## Customisation reference

All customisation flows through `NetworkServiceBuilder` (each `with…` returns
`Self`, so calls chain). Every collaborator has a sensible default.

| Builder method | Overrides | Default |
|---|---|---|
| `withTokenRefreshProvider(_:)` | Token-refresh call | none (required for auth) |
| `withTokenStorage(_:)` | Token persistence | `KeychainTokenStorage` |
| `withNetworkMonitor(_:)` | Connectivity source | `DefaultNetworkMonitor` (`NWPathMonitor`) |
| `withErrorResponseParser(_:)` | Error-body parsing | `DefaultErrorResponseParser` |
| `withErrorHandler(_:)` | Error normalisation | `DefaultNetworkErrorHandler` |
| `withResponseHandler(_:)` | Validation + decoding | `DefaultResponseHandler` |
| `withDecoder(_:)` | JSON decoding strategy | `JSONDecoder()` — pass `RobustJSONDecoder()` for lenient decoding |
| `withLogger(_:)` | Logging backend | `DefaultNetworkLogger` |
| `withConnectivityListener(_:)` | UI connectivity bridge | none (held weakly) |
| `loggingEnabled(_:)` | Toggle logging | `true` |
| `redactSensitiveDataEnabled(_:)` | Toggle log redaction | `true` |

Each call to `build()` returns a **new, independent** service — safe to create
one per test.

`NetworkConfiguration` parameters:

| Parameter | Default | Description |
|---|---|---|
| `baseURL` | — (required) | Prepended to every `APIEndpoint.path` |
| `requestTimeout` | `30s` | Per-request timeout (resets on received data) |
| `resourceTimeout` | `300s` | Absolute ceiling for an entire operation |
| `maxConnectionsPerHost` | `5` | Simultaneous connections to one host |
| `additionalHeaders` | `[:]` | Extra headers on every request |
| `pinnedCertificate` / `pinnedHost` | `nil` | SSL pinning (see above) |

---

## Testing

The library ships with a unit-test suite (81 tests) covering the token-refresh
state machine, error mapping, response validation, robust decoding, and the
request models. Run it from the package root:

```bash
swift test
```

In your own app, everything is protocol-injected, so tests build an isolated
service without touching the Keychain or the network:

```swift
final class InMemoryTokenStorage: TokenStorage { /* … */ }

let service = NetworkServiceBuilder(configuration: testConfig)
    .withTokenStorage(InMemoryTokenStorage())
    .withNetworkMonitor(AlwaysOnlineMonitor())
    .loggingEnabled(false)
    .build()
```

Point `baseURL` at a stub server (e.g. a local mock) and assert against the typed
`NetworkError` cases.

---

## Public API surface

Protocols you implement or depend on:

- `NetworkService`, `MediaDownloadService`
- `APIEndpoint`, `TokenStorage`, `TokenRefreshProvider`, `NetworkMonitor`
- `NetworkErrorHandler`, `ResponseHandler`, `NetworkLogger`,
  `ErrorResponseParser`, `ConnectivityListener`, `DomainService`

Value types:

- `NetworkConfiguration`, `NetworkError`, `NetworkResponse<T>`, `APIRequest`,
  `TokenRefreshResult`, `ServiceContext`, `NetworkTimeouts`, `HTTPMethod`,
  `ParameterEncoding`, `MultipartPart`, `MediaDownloadRequest`,
  `MediaDownloadResult`, `KeychainError`

Provided implementations (replaceable):

- `KeychainTokenStorage`, `DefaultErrorResponseParser`
- `RobustJSONDecoder` — a lenient `JSONDecoder` subclass (opt in via
  `withDecoder(_:)`) with `DefaultValueProvidable` / `TypeMismatchRecoverable`
  recovery hooks, `EnhancedDecodingError` diagnostics, and
  `decodeFlexibleDouble/Int/Bool` container helpers for messy payloads

Builders & bootstrap:

- `NetworkServiceBuilder`, `MediaServiceBuilder`, `NetworkContainer`

See [`NetworkLayer.swift`](LibraryCore/NetworkLayer/Sources/NetworkLayer/NetworkLayer.swift)
for the annotated export list.

---

## License

Released under the [MIT License](LICENSE).
