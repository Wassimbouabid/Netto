//
//  DefaultNetworkErrorHandlerTests.swift
//  NettoTests
//

import XCTest
import Alamofire
@testable import Netto

final class DefaultNetworkErrorHandlerTests: XCTestCase {

    private let handler = DefaultNetworkErrorHandler()

    private func body(_ json: String) -> Data { Data(json.utf8) }

    // MARK: - errorForStatusCode

    func test_status400_mapsToBadRequest_withParsedMessage() {
        let error = handler.errorForStatusCode(400, data: body(#"{"message": "Missing field"}"#), headers: nil)
        XCTAssertEqual(error, .badRequest(message: "Missing field", code: nil, headers: nil))
    }

    func test_status401_mapsToAuthenticationRequired() {
        let error = handler.errorForStatusCode(401, data: nil, headers: nil)
        XCTAssertEqual(error, .authenticationRequired(message: nil, headers: nil))
    }

    func test_status403_mapsToForbidden() {
        let error = handler.errorForStatusCode(403, data: body(#"{"error": "Nope"}"#), headers: nil)
        XCTAssertEqual(error, .forbidden(message: "Nope", headers: nil))
    }

    func test_status404_mapsToNotFound() {
        XCTAssertEqual(handler.errorForStatusCode(404, data: nil, headers: nil), .notFound)
    }

    func test_status405_mapsToMethodNotAllowed() {
        XCTAssertEqual(handler.errorForStatusCode(405, data: nil, headers: nil), .methodNotAllowed)
    }

    func test_status408_mapsToTimeout() {
        XCTAssertEqual(handler.errorForStatusCode(408, data: nil, headers: nil), .timeout)
    }

    func test_status5xx_mapsToServerError_withStatusCode() {
        let error = handler.errorForStatusCode(503, data: body(#"{"message": "Maintenance"}"#), headers: nil)
        XCTAssertEqual(error, .serverError(statusCode: 503, message: "Maintenance", headers: nil))
        XCTAssertEqual(error.statusCode, 503)
    }

    func test_unhandledStatus_mapsToServerError_withFallbackMessage() {
        let error = handler.errorForStatusCode(418, data: nil, headers: nil)
        XCTAssertEqual(
            error,
            .serverError(statusCode: 418, message: "Unexpected status code (418)", headers: nil)
        )
    }

    func test_statusCodeErrors_carryResponseHeaders() {
        let headers = ["Retry-After": "30", "X-Request-Id": "abc-123"]
        let error = handler.errorForStatusCode(503, data: nil, headers: headers)
        XCTAssertEqual(error.responseHeaders, headers)
    }

    // MARK: - handle(_:) passthrough & URLError mapping

    func test_handle_existingNetworkError_isReturnedUnchanged() {
        let original = NetworkError.forbidden(message: "denied", headers: ["A": "b"])
        XCTAssertEqual(handler.handle(original, responseHeaders: nil), original)
    }

    func test_handle_urlErrors_mapToTypedCases() {
        let expectations: [(URLError.Code, NetworkError)] = [
            (.notConnectedToInternet, .noInternet),
            (.timedOut, .timeout),
            (.cannotFindHost, .hostNotFound),
            (.dnsLookupFailed, .hostNotFound),
            (.cannotConnectToHost, .serverUnreachable),
            (.networkConnectionLost, .networkConnectionLost),
            (.cancelled, .requestCancelled),
            (.badURL, .invalidURL),
            (.secureConnectionFailed, .sslError),
            (.serverCertificateUntrusted, .sslError),
        ]

        for (code, expected) in expectations {
            XCTAssertEqual(
                handler.handle(URLError(code), responseHeaders: nil),
                expected,
                "URLError(.\(code)) should map to \(expected)"
            )
        }
    }

    func test_handle_unmappedURLError_mapsToUnknown() {
        let error = handler.handle(URLError(.httpTooManyRedirects), responseHeaders: nil)
        guard case .unknown = error else {
            return XCTFail("Expected .unknown, got \(error)")
        }
    }

    func test_handle_arbitraryError_mapsToUnknown() {
        struct Weird: Error {}
        let error = handler.handle(Weird(), responseHeaders: nil)
        guard case .unknown = error else {
            return XCTFail("Expected .unknown, got \(error)")
        }
    }

    // MARK: - AFError mapping

    func test_handle_afSessionTaskFailed_unwrapsURLError() {
        let afError = AFError.sessionTaskFailed(error: URLError(.networkConnectionLost))
        XCTAssertEqual(handler.handle(afError, responseHeaders: nil), .networkConnectionLost)
    }

    func test_handle_afUnacceptableStatusCode_threadsHeadersThrough() {
        let afError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 500))
        let error = handler.handle(afError, responseHeaders: ["X-Request-Id": "xyz"])

        XCTAssertEqual(error.statusCode, 500)
        XCTAssertEqual(error.responseHeaders, ["X-Request-Id": "xyz"])
    }

    func test_handle_afServerTrustFailure_mapsToSSLError() {
        let afError = AFError.serverTrustEvaluationFailed(
            reason: .noRequiredEvaluator(host: "api.example.com")
        )
        XCTAssertEqual(handler.handle(afError, responseHeaders: nil), .sslError)
    }

    // MARK: - handleDecodingError

    private struct TestKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private func context(_ description: String) -> DecodingError.Context {
        DecodingError.Context(codingPath: [], debugDescription: description)
    }

    func test_decodingKeyNotFound_includesKeyNameInMessage() {
        let error = handler.handleDecodingError(
            DecodingError.keyNotFound(TestKey("userName"), context("key missing"))
        )
        guard case .decodingError(let message) = error else {
            return XCTFail("Expected .decodingError, got \(error)")
        }
        XCTAssertTrue(message.contains("userName"))
    }

    func test_decodingTypeMismatch_includesTypeInMessage() {
        let error = handler.handleDecodingError(
            DecodingError.typeMismatch(Int.self, context("expected Int"))
        )
        guard case .decodingError(let message) = error else {
            return XCTFail("Expected .decodingError, got \(error)")
        }
        XCTAssertTrue(message.contains("Int"))
    }

    func test_decodingValueNotFound_producesDecodingError() {
        let error = handler.handleDecodingError(
            DecodingError.valueNotFound(String.self, context("null value"))
        )
        guard case .decodingError = error else {
            return XCTFail("Expected .decodingError, got \(error)")
        }
    }

    func test_decodingDataCorrupted_producesDecodingError() {
        let error = handler.handleDecodingError(
            DecodingError.dataCorrupted(context("not JSON"))
        )
        guard case .decodingError(let message) = error else {
            return XCTFail("Expected .decodingError, got \(error)")
        }
        XCTAssertTrue(message.contains("corrupted"))
    }

    func test_nonDecodingError_stillProducesDecodingError() {
        struct Other: Error {}
        let error = handler.handleDecodingError(Other())
        guard case .decodingError = error else {
            return XCTFail("Expected .decodingError, got \(error)")
        }
    }
}
