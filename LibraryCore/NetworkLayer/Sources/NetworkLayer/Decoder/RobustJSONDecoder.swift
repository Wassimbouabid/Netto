//
//  RobustJSONDecoder.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 24/12/2025.
//

import Foundation

// MARK: - Flexible Decoding Extensions

extension KeyedDecodingContainer {
    /// Decodes a Double value that might be represented as an Int in JSON or might be null
    func decodeFlexibleDouble(forKey key: Key) -> Double? {
        // First try to decode as Double
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }

        // Then try to decode as Int and convert to Double
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        // Then try to decode as String and convert to Double
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
           let doubleFromString = Double(stringValue) {
            return doubleFromString
        }

        // If nothing works, return nil - don't fail!
        return nil
    }

    /// Decodes an Int value that might be represented as a Double or String in JSON
    func decodeFlexibleInt(forKey key: Key) -> Int? {
        // First try to decode as Int
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        // Then try to decode as Double and convert to Int
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        // Then try to decode as String and convert to Int
        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
           let intFromString = Int(stringValue) {
            return intFromString
        }

        // If nothing works, return nil - don't fail!
        return nil
    }

    /// Decodes a Bool value that might be represented as an Int or String in JSON
    func decodeFlexibleBool(forKey key: Key) -> Bool? {
        // First try to decode as Bool
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        // Then try to decode as Int and convert to Bool
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        // Then try to decode as String and convert to Bool
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let lowercased = stringValue.lowercased()
            if ["true", "yes", "1", "y"].contains(lowercased) {
                return true
            } else if ["false", "no", "0", "n"].contains(lowercased) {
                return false
            }
        }

        // If nothing works, return nil - don't fail!
        return nil
    }

    /// Decodes a value for a given key or returns nil if decoding fails for any reason
    func decodeIfPresentSafely<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        return try? decodeIfPresent(type, forKey: key) ?? nil
    }
}

// MARK: - Custom JSON Decoder

/// A decoder that doesn't crash on typical JSON decoding errors
class RobustJSONDecoder: JSONDecoder {
    override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        do {
            return try super.decode(type, from: data)
        } catch let decodingError as DecodingError {
            // Handle errors that we can recover from
            switch decodingError {
            case .valueNotFound(let valueType, let context):
                // If a non-optional value is null in the JSON, try to provide a default value
                if DefaultValueProvider(for: valueType) != nil {
                    if let extendedType = T.self as? DefaultValueProvidable.Type,
                       let rectifiedInstance = try? extendedType.createWithDefaults(from: data, error: decodingError, using: self) {
                        // If our type can handle missing values
                        if let result = rectifiedInstance as? T {
                            return result
                        }
                    }
                }
                // If we can't recover, rethrow with better context
                throw EnhancedDecodingError.enhanceValueNotFound(
                    valueType, context: context,
                    message: "JSON contained null for non-optional value"
                )

            case .keyNotFound(let key, let context):
                // If a required key is missing, try to provide a default value
                if let extendedType = T.self as? DefaultValueProvidable.Type,
                   let rectifiedInstance = try? extendedType.createWithDefaults(from: data, error: decodingError, using: self) {
                    // If our type can handle missing keys
                    if let result = rectifiedInstance as? T {
                        return result
                    }
                }
                // If we can't recover, rethrow with better context
                throw EnhancedDecodingError.enhanceKeyNotFound(
                    key, context: context,
                    message: "JSON missing required key '\(key.stringValue)'"
                )

            case .typeMismatch(let type, let context):
                // Try to recover from type mismatches by using a type converter
                if let extendedType = T.self as? TypeMismatchRecoverable.Type,
                   let rectifiedInstance = try? extendedType.recoverFromTypeMismatch(from: data, expected: type, context: context, using: self) {
                    if let result = rectifiedInstance as? T {
                        return result
                    }
                }
                // If we can't recover, rethrow with better context
                throw EnhancedDecodingError.enhanceTypeMismatch(
                    type, context: context,
                    message: "JSON contained wrong type for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))'"
                )

            case .dataCorrupted(let context):
                // We generally can't recover from corrupted data
                throw EnhancedDecodingError.enhanceDataCorrupted(
                    context: context,
                    message: "JSON data is corrupted or malformed"
                )

            @unknown default:
                throw decodingError
            }
        } catch {
            // Handle other errors
            throw error
        }
    }
}

// MARK: - Protocols for Default Values and Type Conversion

/// Protocol for types that can create themselves with default values
protocol DefaultValueProvidable {
    static func createWithDefaults(from data: Data, error: DecodingError, using decoder: JSONDecoder) throws -> Any
}

/// Protocol for types that can recover from type mismatches
protocol TypeMismatchRecoverable {
    static func recoverFromTypeMismatch(from data: Data, expected: Any.Type, context: DecodingError.Context, using decoder: JSONDecoder) throws -> Any
}

/// Helper for providing default values for basic types
struct DefaultValueProvider {
    let getValue: () -> Any

    init?(for type: Any.Type) {
        switch type {
        case is String.Type:
            getValue = { "" }
        case is Int.Type:
            getValue = { 0 }
        case is Double.Type:
            getValue = { 0.0 }
        case is Bool.Type:
            getValue = { false }
        case is [String].Type:
            getValue = { [] as [String] }
        case is [Int].Type:
            getValue = { [] as [Int] }
        case is [Double].Type:
            getValue = { [] as [Double] }
        case is [String: String].Type:
            getValue = { [:] as [String: String] }
        case is [String: Any].Type:
            getValue = { [:] as [String: Any] }
        default:
            return nil
        }
    }
}

// MARK: - Enhanced Error Types

/// Enhanced decoding errors with better context
enum EnhancedDecodingError: Error, LocalizedError {
    case enhanceValueNotFound(Any.Type, context: DecodingError.Context, message: String)
    case enhanceKeyNotFound(CodingKey, context: DecodingError.Context, message: String)
    case enhanceTypeMismatch(Any.Type, context: DecodingError.Context, message: String)
    case enhanceDataCorrupted(context: DecodingError.Context, message: String)

    var errorDescription: String? {
        switch self {
        case .enhanceValueNotFound(let type, let context, let message):
            return "\(message). Expected type: \(type). Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .enhanceKeyNotFound(let key, let context, let message):
            return "\(message). Path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")).\(key.stringValue)"
        case .enhanceTypeMismatch(let type, _, let message):
            return "\(message). Expected type: \(type)"
        case .enhanceDataCorrupted(let context, let message):
            return "\(message). Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        }
    }
}
