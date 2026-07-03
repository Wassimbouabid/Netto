//
//  DomainServiceTests.swift
//  NetworkLayerTests
//

import XCTest
@testable import NetworkLayer

private struct PaymentsService: DomainService {
    static let context = ServiceContext(rawValue: "payments")
}

private struct PaymentDeclined: Error {}

final class DomainServiceTests: XCTestCase {

    private let service = PaymentsService()

    func test_withContext_success_returnsOperationValue() async throws {
        let value = try await service.withContext { "ok" }
        XCTAssertEqual(value, "ok")
    }

    func test_withContext_infrastructureError_passesThroughUnchanged() async {
        do {
            _ = try await service.withContext { () -> String in
                throw NetworkError.timeout
            }
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .timeout, "Infrastructure errors must not be wrapped")
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_withContext_httpError_passesThroughUnchanged() async {
        let original = NetworkError.serverError(statusCode: 500, message: "boom", headers: nil)
        do {
            _ = try await service.withContext { () -> String in throw original }
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, original)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_withContext_nonNetworkError_isWrappedWithServiceContext() async {
        do {
            _ = try await service.withContext { () -> String in
                throw PaymentDeclined()
            }
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            guard case .domainError(let context, let underlying) = error else {
                return XCTFail("Expected .domainError, got \(error)")
            }
            XCTAssertEqual(context, PaymentsService.context)
            XCTAssertTrue(underlying is PaymentDeclined)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_withContext_existingDomainError_isRewrappedWithNewContext() async {
        let foreign = NetworkError.domainError(
            context: ServiceContext(rawValue: "auth"),
            underlyingError: PaymentDeclined()
        )
        do {
            _ = try await service.withContext { () -> String in throw foreign }
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            guard case .domainError(let context, _) = error else {
                return XCTFail("Expected .domainError, got \(error)")
            }
            XCTAssertEqual(context, PaymentsService.context,
                           "A domain error crossing a service boundary picks up the new context")
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }
}
