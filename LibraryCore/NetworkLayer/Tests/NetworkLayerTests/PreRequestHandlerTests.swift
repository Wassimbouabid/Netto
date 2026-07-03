//
//  PreRequestHandlerTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

final class PreRequestHandlerTests: XCTestCase {

    private func makeRequest() -> APIRequest {
        APIRequest(rawURL: "https://api.example.com/users/me")
    }

    // MARK: - Header attachment

    func test_prepare_withValidToken_attachesBearerAndAcceptHeaders() async throws {
        let storage = InMemoryTokenStorage(
            accessToken: "valid-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let provider = CountingRefreshProvider()
        let handler  = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: provider)

        var request = makeRequest()
        try await handler.prepare(&request)

        XCTAssertEqual(request.headers?["Authorization"], "Bearer valid-token")
        XCTAssertEqual(request.headers?["Accept"], "application/json")
        XCTAssertEqual(provider.callCount, 0, "A non-expired token must not trigger a refresh")
    }

    func test_prepare_preservesExistingAcceptHeader() async throws {
        let storage = InMemoryTokenStorage(
            accessToken: "valid-token",
            expiresAt: Date().addingTimeInterval(3600)
        )
        let handler = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: nil)

        var request = makeRequest()
        request.headers = ["Accept": "application/xml", "X-Custom": "abc"]
        try await handler.prepare(&request)

        XCTAssertEqual(request.headers?["Accept"], "application/xml")
        XCTAssertEqual(request.headers?["X-Custom"], "abc")
        XCTAssertEqual(request.headers?["Authorization"], "Bearer valid-token")
    }

    // MARK: - Missing token

    func test_prepare_withoutStoredToken_throwsAuthenticationRequired() async {
        let handler = PreRequestHandlerImpl(
            tokenStorage: InMemoryTokenStorage(),
            refreshProvider: CountingRefreshProvider()
        )

        var request = makeRequest()
        do {
            try await handler.prepare(&request)
            XCTFail("Expected authenticationRequired")
        } catch let error as NetworkError {
            guard case .authenticationRequired = error else {
                return XCTFail("Expected authenticationRequired, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: - Refresh flow

    func test_prepare_withExpiredToken_refreshesAndAttachesNewToken() async throws {
        let storage = InMemoryTokenStorage(
            accessToken: "stale-token",
            expiresAt: Date().addingTimeInterval(-60)
        )
        let provider = CountingRefreshProvider()
        let handler  = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: provider)

        var request = makeRequest()
        try await handler.prepare(&request)

        XCTAssertEqual(provider.callCount, 1)
        XCTAssertEqual(request.headers?["Authorization"], "Bearer new-access")
        XCTAssertEqual(storage.accessToken, "new-access")
        XCTAssertEqual(storage.refreshToken, "new-refresh")
    }

    func test_prepare_withExpiredTokenAndNoProvider_throwsAuthenticationRequired() async {
        let storage = InMemoryTokenStorage(
            accessToken: "stale-token",
            expiresAt: Date().addingTimeInterval(-60)
        )
        let handler = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: nil)

        var request = makeRequest()
        do {
            try await handler.prepare(&request)
            XCTFail("Expected authenticationRequired")
        } catch let error as NetworkError {
            guard case .authenticationRequired = error else {
                return XCTFail("Expected authenticationRequired, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_prepare_refreshFailure_propagatesAndAllowsRetry() async throws {
        let storage = InMemoryTokenStorage(
            accessToken: "stale-token",
            expiresAt: Date().addingTimeInterval(-60)
        )
        let provider = CountingRefreshProvider(failuresBeforeSuccess: 1)
        let handler  = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: provider)

        var request = makeRequest()
        do {
            try await handler.prepare(&request)
            XCTFail("First prepare should fail")
        } catch { /* expected */ }

        // The failed refresh must reset internal state so a retry is possible.
        var retryRequest = makeRequest()
        try await handler.prepare(&retryRequest)

        XCTAssertEqual(provider.callCount, 2)
        XCTAssertEqual(retryRequest.headers?["Authorization"], "Bearer new-access")
    }

    // MARK: - Concurrent refresh deduplication (the key invariant)

    func test_prepare_manyConcurrentCallers_triggerExactlyOneRefresh() async throws {
        let storage = InMemoryTokenStorage(
            accessToken: "stale-token",
            expiresAt: Date().addingTimeInterval(-60)
        )
        // A slow provider widens the race window so all callers pile up
        // while the refresh is in flight.
        let provider = CountingRefreshProvider(delayNanoseconds: 200_000_000)
        let handler  = PreRequestHandlerImpl(tokenStorage: storage, refreshProvider: provider)

        let tokens = try await withThrowingTaskGroup(of: String?.self) { group -> [String?] in
            for _ in 0..<20 {
                group.addTask {
                    var request = APIRequest(rawURL: "https://api.example.com/users/me")
                    try await handler.prepare(&request)
                    return request.headers?["Authorization"]
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(provider.callCount, 1, "Concurrent callers must share a single refresh")
        XCTAssertEqual(tokens.count, 20)
        XCTAssertTrue(
            tokens.allSatisfy { $0 == "Bearer new-access" },
            "Every caller must receive the refreshed token"
        )
    }
}
