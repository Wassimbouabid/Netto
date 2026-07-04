//
//  Encodable+toDictionary.swift
//  Netto
//
//  Created by Bouabid Wassim on 25/12/2025.
//

import Foundation

extension Encodable {
    /// Converts Encodable to dictionary for network requests
    ///
    /// Uses JSONEncoder for consistent serialization with API contract.
    /// Respects CodingKeys for proper snake_case transformation.
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}
