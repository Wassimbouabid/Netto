//
//  RobustJSONDecoderTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

// MARK: - Fixtures

/// Model exercising the flexible decoding helpers.
private struct FlexibleModel: Decodable {
    let price: Double?
    let count: Int?
    let active: Bool?

    private enum CodingKeys: String, CodingKey {
        case price, count, active
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        price  = container.decodeFlexibleDouble(forKey: .price)
        count  = container.decodeFlexibleInt(forKey: .count)
        active = container.decodeFlexibleBool(forKey: .active)
    }
}

private struct StrictUser: Decodable {
    let id: Int
    let name: String
}

/// Model that opts in to default-value recovery on missing keys.
private struct TolerantUser: Decodable, DefaultValueProvidable {
    let id: Int
    let name: String

    static func createWithDefaults(from data: Data, error: DecodingError, using decoder: JSONDecoder) throws -> Any {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return TolerantUser(
            id:   object["id"] as? Int ?? 0,
            name: object["name"] as? String ?? ""
        )
    }
}

// MARK: - Flexible container helpers

final class FlexibleDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> FlexibleModel {
        try JSONDecoder().decode(FlexibleModel.self, from: Data(json.utf8))
    }

    func test_flexibleDouble_acceptsDoubleIntAndString() throws {
        XCTAssertEqual(try decode(#"{"price": 9.5}"#).price, 9.5)
        XCTAssertEqual(try decode(#"{"price": 9}"#).price, 9.0)
        XCTAssertEqual(try decode(#"{"price": "9.5"}"#).price, 9.5)
        XCTAssertNil(try decode(#"{"price": "not a number"}"#).price)
        XCTAssertNil(try decode(#"{}"#).price)
    }

    func test_flexibleInt_acceptsIntDoubleAndString() throws {
        XCTAssertEqual(try decode(#"{"count": 3}"#).count, 3)
        XCTAssertEqual(try decode(#"{"count": 3.7}"#).count, 3)
        XCTAssertEqual(try decode(#"{"count": "3"}"#).count, 3)
        XCTAssertNil(try decode(#"{"count": "many"}"#).count)
    }

    func test_flexibleBool_acceptsBoolIntAndStrings() throws {
        XCTAssertEqual(try decode(#"{"active": true}"#).active, true)
        XCTAssertEqual(try decode(#"{"active": 1}"#).active, true)
        XCTAssertEqual(try decode(#"{"active": 0}"#).active, false)
        XCTAssertEqual(try decode(#"{"active": "yes"}"#).active, true)
        XCTAssertEqual(try decode(#"{"active": "NO"}"#).active, false)
        XCTAssertNil(try decode(#"{"active": "maybe"}"#).active)
    }
}

// MARK: - RobustJSONDecoder

final class RobustJSONDecoderTests: XCTestCase {

    private let decoder = RobustJSONDecoder()

    func test_decode_validJSON_behavesLikePlainDecoder() throws {
        let user = try decoder.decode(StrictUser.self, from: Data(#"{"id": 1, "name": "W"}"#.utf8))
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "W")
    }

    func test_missingKey_throwsEnhancedError_namingTheKey() {
        XCTAssertThrowsError(
            try decoder.decode(StrictUser.self, from: Data(#"{"id": 1}"#.utf8))
        ) { error in
            guard case EnhancedDecodingError.enhanceKeyNotFound = error else {
                return XCTFail("Expected enhanceKeyNotFound, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("name"))
        }
    }

    func test_typeMismatch_throwsEnhancedError() {
        XCTAssertThrowsError(
            try decoder.decode(StrictUser.self, from: Data(#"{"id": "x", "name": "W"}"#.utf8))
        ) { error in
            guard case EnhancedDecodingError.enhanceTypeMismatch = error else {
                return XCTFail("Expected enhanceTypeMismatch, got \(error)")
            }
        }
    }

    func test_malformedJSON_throwsEnhancedDataCorrupted() {
        XCTAssertThrowsError(
            try decoder.decode(StrictUser.self, from: Data("###".utf8))
        ) { error in
            guard case EnhancedDecodingError.enhanceDataCorrupted = error else {
                return XCTFail("Expected enhanceDataCorrupted, got \(error)")
            }
        }
    }

    func test_missingKey_recoversViaDefaultValueProvidable() throws {
        let user = try decoder.decode(TolerantUser.self, from: Data(#"{"id": 5}"#.utf8))
        XCTAssertEqual(user.id, 5)
        XCTAssertEqual(user.name, "", "Missing key must fall back to the type's default")
    }

    // MARK: - Integration with the response pipeline

    func test_responseHandler_withRobustDecoder_surfacesEnhancedMessage() {
        let handler = DefaultResponseHandler(
            errorHandler: DefaultNetworkErrorHandler(),
            decoder: RobustJSONDecoder()
        )

        XCTAssertThrowsError(
            try handler.decode(Data(#"{"id": 1}"#.utf8), as: StrictUser.self)
        ) { error in
            guard case .decodingError(let message) = error as? NetworkError else {
                return XCTFail("Expected NetworkError.decodingError, got \(error)")
            }
            XCTAssertTrue(message.contains("name"), "Enhanced message should name the missing key: \(message)")
            XCTAssertFalse(message.hasPrefix("Unknown decoding error"),
                           "EnhancedDecodingError must not be reported as unknown")
        }
    }
}
