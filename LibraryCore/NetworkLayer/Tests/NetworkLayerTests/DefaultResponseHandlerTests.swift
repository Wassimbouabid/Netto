//
//  DefaultResponseHandlerTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

final class DefaultResponseHandlerTests: XCTestCase {

    private let handler = DefaultResponseHandler(errorHandler: DefaultNetworkErrorHandler())

    private struct User: Decodable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - validate

    func test_validate_2xxWithBody_passes() throws {
        let response = makeHTTPResponse(statusCode: 200)
        XCTAssertNoThrow(try handler.validate(Data(#"{"ok":true}"#.utf8), response: response))
    }

    func test_validate_204WithEmptyBody_passes() {
        let response = makeHTTPResponse(statusCode: 204)
        XCTAssertNoThrow(try handler.validate(Data(), response: response))
    }

    func test_validate_200EmptyBodyWithDeclaredContentLength_throwsEmptyResponse() {
        let response = makeHTTPResponse(statusCode: 200, headers: ["Content-Length": "42"])
        XCTAssertThrowsError(try handler.validate(Data(), response: response)) { error in
            XCTAssertEqual(error as? NetworkError, .emptyResponse)
        }
    }

    func test_validate_200EmptyBodyWithoutContentLength_passes() {
        // Unknown content length (-1) must not be treated as "content expected".
        let response = makeHTTPResponse(statusCode: 200)
        XCTAssertNoThrow(try handler.validate(Data(), response: response))
    }

    func test_validate_404_throwsNotFound() {
        let response = makeHTTPResponse(statusCode: 404)
        XCTAssertThrowsError(try handler.validate(Data(), response: response)) { error in
            XCTAssertEqual(error as? NetworkError, .notFound)
        }
    }

    func test_validate_500_throwsServerError_withParsedMessageAndHeaders() {
        let response = makeHTTPResponse(statusCode: 500, headers: ["X-Request-Id": "req-1"])
        let data = Data(#"{"message": "DB down"}"#.utf8)

        XCTAssertThrowsError(try handler.validate(data, response: response)) { error in
            guard let networkError = error as? NetworkError,
                  case .serverError(let code, let message, _) = networkError else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "DB down")
            XCTAssertEqual(networkError.responseHeaders?["X-Request-Id"], "req-1")
        }
    }

    func test_validate_401_throwsAuthenticationRequired() {
        let response = makeHTTPResponse(statusCode: 401)
        XCTAssertThrowsError(try handler.validate(Data(), response: response)) { error in
            guard case .authenticationRequired = error as? NetworkError else {
                return XCTFail("Expected .authenticationRequired, got \(error)")
            }
        }
    }

    // MARK: - decode

    func test_decode_validJSON_returnsModel() throws {
        let data = Data(#"{"id": 7, "name": "Wassim"}"#.utf8)
        let user = try handler.decode(data, as: User.self)
        XCTAssertEqual(user, User(id: 7, name: "Wassim"))
    }

    func test_decode_missingKey_throwsDecodingErrorWithKeyName() {
        let data = Data(#"{"id": 7}"#.utf8)
        XCTAssertThrowsError(try handler.decode(data, as: User.self)) { error in
            guard case .decodingError(let message) = error as? NetworkError else {
                return XCTFail("Expected .decodingError, got \(error)")
            }
            XCTAssertTrue(message.contains("name"), "Message should name the missing key: \(message)")
        }
    }

    func test_decode_malformedJSON_throwsDecodingError() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try handler.decode(data, as: User.self)) { error in
            guard case .decodingError = error as? NetworkError else {
                return XCTFail("Expected .decodingError, got \(error)")
            }
        }
    }
}
