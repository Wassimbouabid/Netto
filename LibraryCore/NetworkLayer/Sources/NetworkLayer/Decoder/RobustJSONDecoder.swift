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
