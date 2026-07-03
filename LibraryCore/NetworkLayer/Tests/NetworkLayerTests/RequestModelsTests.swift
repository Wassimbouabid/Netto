//
//  RequestModelsTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

// MARK: - Test endpoint

private struct StubEndpoint: APIEndpoint {
    var path: String
    var method: HTTPMethod = .get
    var parameters: [String: Any]? = nil
    var encoding: ParameterEncoding = .json
    var headers: [String: String]? = nil
}

// MARK: - APIRequest

final class APIRequestTests: XCTestCase {

    func test_urlJoining_normalisesSlashes() {
        let cases: [(base: String, path: String)] = [
            ("https://api.example.com",  "users/42"),
            ("https://api.example.com/", "users/42"),
            ("https://api.example.com",  "/users/42"),
            ("https://api.example.com/", "/users/42"),
        ]

        for (base, path) in cases {
            let request = APIRequest(
                endpoint: StubEndpoint(path: path),
                baseURL: URL(string: base)!
            )
            XCTAssertEqual(
                request.url, "https://api.example.com/users/42",
                "base '\(base)' + path '\(path)' should normalise"
            )
        }
    }

    func test_urlJoining_preservesBasePathComponent() {
        let request = APIRequest(
            endpoint: StubEndpoint(path: "/users"),
            baseURL: URL(string: "https://api.example.com/v1")!
        )
        XCTAssertEqual(request.url, "https://api.example.com/v1/users")
    }

    func test_endpointInit_copiesAllFields() {
        let endpoint = StubEndpoint(
            path: "items",
            method: .post,
            parameters: ["q": "swift"],
            headers: ["X-Trace": "1"]
        )
        let request = APIRequest(endpoint: endpoint, baseURL: URL(string: "https://api.example.com")!)

        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.parameters?["q"] as? String, "swift")
        XCTAssertEqual(request.headers?["X-Trace"], "1")
        XCTAssertNil(request.timeout, "StubEndpoint uses the protocol's default nil timeout")
    }

    func test_rawURLInit_producesMinimalGETRequest() {
        let request = APIRequest(rawURL: "https://cdn.example.com/image.jpg")

        XCTAssertEqual(request.url, "https://cdn.example.com/image.jpg")
        XCTAssertEqual(request.method, .get)
        XCTAssertNil(request.parameters)
        XCTAssertNil(request.headers)
        XCTAssertNil(request.timeout)
    }

    func test_endpointDefaults() {
        let endpoint = StubEndpoint(path: "x")
        XCTAssertFalse(endpoint.skipsPreRequestHandler)
        XCTAssertNil(endpoint.timeout)
        XCTAssertNil(endpoint.customBaseURL)
    }
}

// MARK: - MediaDownloadRequest

final class MediaDownloadRequestTests: XCTestCase {

    func test_identity_basedOnIdAndUrlOnly() {
        let a = MediaDownloadRequest(id: "1", url: "https://x/a.jpg", maxRetryAttempts: 1)
        let b = MediaDownloadRequest(id: "1", url: "https://x/a.jpg", maxRetryAttempts: 9,
                                     metadata: ["k": "v"])

        XCTAssertEqual(a, b, "Retry count and metadata must not affect identity")
        XCTAssertEqual(a.hashValue, b.hashValue)

        XCTAssertNotEqual(a, MediaDownloadRequest(id: "2", url: "https://x/a.jpg"))
        XCTAssertNotEqual(a, MediaDownloadRequest(id: "1", url: "https://x/b.jpg"))
    }

    func test_usableAsDictionaryKey() {
        let a = MediaDownloadRequest(id: "1", url: "https://x/a.jpg")
        let duplicate = MediaDownloadRequest(id: "1", url: "https://x/a.jpg", metadata: ["m": 1])

        var results: [MediaDownloadRequest: String] = [:]
        results[a] = "first"
        results[duplicate] = "second"

        XCTAssertEqual(results.count, 1, "Equal requests must collapse to one key")
        XCTAssertEqual(results[a], "second")
    }
}

// MARK: - ServiceContext

final class ServiceContextTests: XCTestCase {

    func test_rawRepresentable_roundTrip() {
        let context = ServiceContext(rawValue: "payments")
        XCTAssertEqual(context.rawValue, "payments")
        XCTAssertEqual(context.resourceName, "payments")
        XCTAssertEqual(context, ServiceContext(rawValue: "payments"))
        XCTAssertNotEqual(context, ServiceContext(rawValue: "auth"))
    }
}
