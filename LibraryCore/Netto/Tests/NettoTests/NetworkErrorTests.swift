//
//  NetworkErrorTests.swift
//  NettoTests
//

import XCTest
@testable import Netto

final class NetworkErrorTests: XCTestCase {

    // MARK: - statusCode

    func test_statusCode_forHTTPErrors() {
        XCTAssertEqual(NetworkError.badRequest(message: nil, code: nil, headers: nil).statusCode, 400)
        XCTAssertEqual(NetworkError.authenticationRequired(message: nil, headers: nil).statusCode, 401)
        XCTAssertEqual(NetworkError.forbidden(message: nil, headers: nil).statusCode, 403)
        XCTAssertEqual(NetworkError.notFound.statusCode, 404)
        XCTAssertEqual(NetworkError.methodNotAllowed.statusCode, 405)
        XCTAssertEqual(NetworkError.serverError(statusCode: 502, message: nil, headers: nil).statusCode, 502)
    }

    func test_statusCode_isNilForNonHTTPErrors() {
        XCTAssertNil(NetworkError.noInternet.statusCode)
        XCTAssertNil(NetworkError.timeout.statusCode)
        XCTAssertNil(NetworkError.decodingError("x").statusCode)
    }

    // MARK: - responseHeaders

    func test_responseHeaders_exposedForHeaderCarryingCases() {
        let headers = ["Retry-After": "60"]
        XCTAssertEqual(NetworkError.badRequest(message: nil, code: nil, headers: headers).responseHeaders, headers)
        XCTAssertEqual(NetworkError.authenticationRequired(message: nil, headers: headers).responseHeaders, headers)
        XCTAssertEqual(NetworkError.forbidden(message: nil, headers: headers).responseHeaders, headers)
        XCTAssertEqual(NetworkError.serverError(statusCode: 500, message: nil, headers: headers).responseHeaders, headers)
        XCTAssertNil(NetworkError.notFound.responseHeaders)
    }

    // MARK: - Equatable semantics

    func test_equality_simpleCases() {
        XCTAssertEqual(NetworkError.noInternet, .noInternet)
        XCTAssertEqual(NetworkError.timeout, .timeout)
        XCTAssertNotEqual(NetworkError.noInternet, .timeout)
    }

    func test_equality_comparesMessages_butIgnoresHeaders() {
        // Headers are intentionally excluded from equality.
        XCTAssertEqual(
            NetworkError.serverError(statusCode: 500, message: "boom", headers: ["A": "1"]),
            NetworkError.serverError(statusCode: 500, message: "boom", headers: ["B": "2"])
        )
        XCTAssertNotEqual(
            NetworkError.serverError(statusCode: 500, message: "boom", headers: nil),
            NetworkError.serverError(statusCode: 500, message: "other", headers: nil)
        )
        XCTAssertNotEqual(
            NetworkError.serverError(statusCode: 500, message: "boom", headers: nil),
            NetworkError.serverError(statusCode: 503, message: "boom", headers: nil)
        )
    }

    func test_equality_domainError_comparesContextOnly() {
        struct ErrA: Error {}
        struct ErrB: Error {}
        let context = ServiceContext(rawValue: "payments")

        XCTAssertEqual(
            NetworkError.domainError(context: context, underlyingError: ErrA()),
            NetworkError.domainError(context: context, underlyingError: ErrB())
        )
        XCTAssertNotEqual(
            NetworkError.domainError(context: context, underlyingError: ErrA()),
            NetworkError.domainError(context: ServiceContext(rawValue: "auth"), underlyingError: ErrA())
        )
    }

    // MARK: - Classification

    func test_isInfrastructureError_trueForAllExceptDomainError() {
        XCTAssertTrue(NetworkError.noInternet.isInfrastructureError)
        XCTAssertTrue(NetworkError.serverError(statusCode: 500, message: nil, headers: nil).isInfrastructureError)
        XCTAssertTrue(NetworkError.decodingError("x").isInfrastructureError)

        struct Domain: Error {}
        let domainError = NetworkError.domainError(
            context: ServiceContext(rawValue: "x"), underlyingError: Domain()
        )
        XCTAssertFalse(domainError.isInfrastructureError)
    }

    func test_isServerDownError() {
        XCTAssertTrue(NetworkError.serverUnreachable.isServerDownError)
        XCTAssertTrue(NetworkError.hostNotFound.isServerDownError)
        XCTAssertTrue(NetworkError.timeout.isServerDownError)
        XCTAssertTrue(NetworkError.serverError(statusCode: 503, message: nil, headers: nil).isServerDownError)

        XCTAssertFalse(NetworkError.badRequest(message: nil, code: nil, headers: nil).isServerDownError)
        XCTAssertFalse(NetworkError.notFound.isServerDownError)
    }

    func test_supportsOfflineMode() {
        XCTAssertTrue(NetworkError.noInternet.supportsOfflineMode)
        XCTAssertTrue(NetworkError.networkConnectionLost.supportsOfflineMode)
        XCTAssertTrue(NetworkError.serverError(statusCode: 500, message: nil, headers: nil).supportsOfflineMode)

        XCTAssertFalse(NetworkError.forbidden(message: nil, headers: nil).supportsOfflineMode)
        XCTAssertFalse(NetworkError.decodingError("x").supportsOfflineMode)
    }

    // MARK: - LocalizedError

    func test_errorDescription_prefersServerMessage_overFallback() {
        XCTAssertEqual(
            NetworkError.badRequest(message: "Field X is required", code: nil, headers: nil).errorDescription,
            "Field X is required"
        )
        XCTAssertEqual(
            NetworkError.badRequest(message: nil, code: nil, headers: nil).errorDescription,
            "Invalid request. Please try again."
        )
    }

    func test_errorDescription_isNeverNil() {
        let samples: [NetworkError] = [
            .noInternet, .timeout, .hostNotFound, .serverUnreachable,
            .networkConnectionLost, .sslError, .invalidURL, .invalidData,
            .requestCancelled, .decodingError("d"), .emptyResponse, .invalidResponse,
            .badRequest(message: nil, code: nil, headers: nil),
            .authenticationRequired(message: nil, headers: nil),
            .forbidden(message: nil, headers: nil), .notFound, .methodNotAllowed,
            .serverError(statusCode: 500, message: nil, headers: nil),
            .unknown(underlying: nil),
        ]
        for error in samples {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Empty description for \(error)")
        }
    }
}
