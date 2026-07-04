//
//  DomainService.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 29/12/2025.
//

import Foundation

/// All service implementations must conform and define their context
public protocol DomainService {
    /// Domain context - compiler enforces implementation
    static var context: ServiceContext { get }
}

public extension DomainService {
    /// Wraps operations with automatic error contextualization
    /// - Infrastructure errors (HTTP, connectivity): pass through unchanged
    /// - Domain errors: wrapped with context
    func withContext<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let networkError as NetworkError {
            // Infrastructure errors pass through unchanged
            if networkError.isInfrastructureError {
                throw networkError
            }
            // Domain errors get context
            throw NetworkError.domainError(context: Self.context, underlyingError: networkError)
        } catch {
            // Non-network errors get context
            throw NetworkError.domainError(context: Self.context, underlyingError: error)
        }
    }
}
