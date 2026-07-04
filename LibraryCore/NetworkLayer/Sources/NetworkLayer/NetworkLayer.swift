// NetworkLayer — public API surface
//
// ┌─────────────────────────────────────────────────────────────────────┐
// │  Bootstrap (call once at app startup, before any network request)   │
// │                                                                     │
// │  let config = NetworkConfiguration(                                 │
// │      baseURL: URL(string: "https://api.example.com")!               │
// │  )                                                                  │
// │                                                                     │
// │  NetworkContainer.shared.configure(                                 │
// │      using: NetworkServiceBuilder(configuration: config)            │
// │          .withTokenRefreshProvider(MyRefresher())                   │
// │  )                                                                  │
// │                                                                     │
// │  // Optional – only if your app downloads media                     │
// │  NetworkContainer.shared.configureMedia(                            │
// │      using: MediaServiceBuilder(configuration: config)              │
// │  )                                                                  │
// └─────────────────────────────────────────────────────────────────────┘
//
// Public types exported by this module:
//
//  Protocols
//    • NetworkService          – make network requests
//    • MediaDownloadService    – download binary media
//    • APIEndpoint             – describe a single endpoint
//    • TokenStorage            – store/retrieve auth tokens
//    • TokenRefreshProvider    – perform a token-refresh call
//    • NetworkMonitor          – observe connectivity changes
//    • NetworkErrorHandler     – normalise errors; injectable via builder
//    • ResponseHandler         – validate + decode responses; injectable via builder
//    • NetworkLogger           – log requests/responses/errors; injectable via builder
//    • ErrorResponseParser     – extract error messages from response bodies
//    • ConnectivityListener    – UI bridge for no-internet / restored events
//
//  Value types
//    • NetworkConfiguration    – base URL, timeouts, extra headers
//    • NetworkError            – typed errors thrown by the layer
//    • NetworkResponse<T>      – decoded body + HTTP headers + status code
//    • APIRequest              – fully-prepared request passed to NetworkLogger methods
//    • TokenRefreshResult      – payload returned by TokenRefreshProvider
//    • ServiceContext          – domain tag for contextualised errors
//    • NetworkTimeouts         – recommended timeout constants
//    • HTTPMethod              – GET / POST / PUT / DELETE / PATCH
//    • ParameterEncoding       – json / url / multipart / custom
//    • MultipartPart           – a single field in a multipart/form-data body
//    • KeychainError           – Keychain-specific save failures
//
//  Default implementations (concrete; can be replaced via builders)
//    • KeychainTokenStorage          – Keychain-backed token storage
//    • DefaultErrorResponseParser    – parses common error/message/errorMessage JSON keys
//    • RobustJSONDecoder             – lenient JSONDecoder; opt in via NetworkServiceBuilder.withDecoder(_:)
//
//  Builders (construct services with fluent configuration)
//    • NetworkServiceBuilder   – wires and builds a NetworkService
//    • MediaServiceBuilder     – wires and builds a MediaDownloadService
//
//  Bootstrap / singleton cache
//    • NetworkContainer        – optional singleton that holds built services
//                                (pure constructor injection; no third-party DI framework)
