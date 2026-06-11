//
//  Alamofire+Utils.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 25/12/2025.
//

internal import Alamofire
import Foundation

/// Extension to convert APIRequest HTTP method to Alamofire's equivalent.
extension HTTPMethod {
    /// Converts `HTTPMethod` to Alamofire's equivalent.
    ///
    /// - Returns: The corresponding Alamofire HTTP method.
    func toAlamofire() -> Alamofire.HTTPMethod {
        Alamofire.HTTPMethod(rawValue: self.rawValue.uppercased())
    }
}

/// Extension to convert APIRequest parameter encoding to Alamofire's equivalent.
extension ParameterEncoding {
    /// Converts `ParameterEncoding` to Alamofire's equivalent.
    ///
    /// - Note: `.multipart` and `.custom` are handled by dedicated code paths
    ///   in `NetworkManager` and must never reach this conversion.
    func toAlamofire() -> Alamofire.ParameterEncoding {
        switch self {
        case .json:
            return JSONEncoding.default
        case .url:
            return URLEncoding.default
        case .multipart, .custom:
            // Both are handled by dedicated upload/request paths in NetworkManager.
            assertionFailure("toAlamofire() must not be called for .\(self) — use the dedicated path in NetworkManager.")
            return JSONEncoding.default
        }
    }
}

/// Extension to convert header dictionary to Alamofire's HTTPHeaders.
extension Dictionary where Key == String, Value == String {
    /// Converts `[String: String]` dictionary to `Alamofire.HTTPHeaders`.
    ///
    /// - Returns: Alamofire HTTP headers.
    func toAlamofire() -> HTTPHeaders {
        HTTPHeaders(self)
    }
}
