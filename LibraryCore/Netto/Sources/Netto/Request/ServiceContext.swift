//
//  ServiceContext.swift
//

import Foundation

/// Identifies which feature domain is performing a network operation.
///
/// Defined as a value-type backed by a `String` so consuming apps can declare
/// their own domain constants via `extension ServiceContext` without touching
/// the library itself.
///
/// ```swift
/// // In the consuming app:
/// extension ServiceContext {
///     static let authentication = ServiceContext(rawValue: "authentication")
///     static let userProfile    = ServiceContext(rawValue: "userProfile")
/// }
/// ```
public struct ServiceContext: RawRepresentable, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Human-readable name used in error messages.
    public var resourceName: String { rawValue }
}
