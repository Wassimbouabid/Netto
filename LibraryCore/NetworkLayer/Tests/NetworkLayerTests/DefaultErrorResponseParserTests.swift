//
//  DefaultErrorResponseParserTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

final class DefaultErrorResponseParserTests: XCTestCase {

    private let parser = DefaultErrorResponseParser()

    private func parse(_ string: String) -> String? {
        parser.extractMessage(from: Data(string.utf8))
    }

    // MARK: - JSON envelope keys

    func test_extractsErrorKey() {
        XCTAssertEqual(parse(#"{"error": "Something broke"}"#), "Something broke")
    }

    func test_extractsMessageKey() {
        XCTAssertEqual(parse(#"{"message": "Invalid input"}"#), "Invalid input")
    }

    func test_extractsErrorMessageKey() {
        XCTAssertEqual(parse(#"{"errorMessage": "Denied"}"#), "Denied")
    }

    func test_extractsDetailsKey() {
        XCTAssertEqual(parse(#"{"details": "Missing header"}"#), "Missing header")
    }

    func test_errorKey_winsOverMessageKey() {
        XCTAssertEqual(
            parse(#"{"message": "second", "error": "first"}"#),
            "first",
            "'error' has priority over 'message'"
        )
    }

    // MARK: - Plain-text fallback

    func test_plainText_returnedAsIs() {
        XCTAssertEqual(parse("Service temporarily unavailable"), "Service temporarily unavailable")
    }

    func test_htmlBody_returnsNil() {
        XCTAssertNil(parse("<html><body>502 Bad Gateway</body></html>"))
    }

    func test_largeBody_returnsNil() {
        let large = String(repeating: "x", count: 2000)
        XCTAssertNil(parse(large))
    }

    func test_emptyData_returnsNil() {
        XCTAssertNil(parser.extractMessage(from: Data()))
    }

    func test_jsonWithoutRecognisedKeys_fallsBackToRawText() {
        // Documents current behavior: an unrecognised (small, non-HTML) JSON body
        // falls through to the plain-text branch and is returned verbatim.
        XCTAssertEqual(parse(#"{"foo": "bar"}"#), #"{"foo": "bar"}"#)
    }
}
