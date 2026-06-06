//
//  APIRequest.swift
//

import Foundation

// MARK: - HTTPMethod

/// Supported HTTP methods. Defined here so consuming apps never import Alamofire directly.
public enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
    case patch  = "PATCH"
}

// MARK: - MultipartPart

/// A single field in a `multipart/form-data` request.
///
/// Use `ParameterEncoding.multipart([MultipartPart])` to compose a multipart body:
/// ```swift
/// var encoding: ParameterEncoding {
///     .multipart([
///         .init(name: "title",  .text("Profile photo")),
///         .init(name: "avatar", .data(imageData, mimeType: "image/jpeg", filename: "avatar.jpg")),
///     ])
/// }
/// ```
public struct MultipartPart {
    /// The name of the form field (`name` parameter in `Content-Disposition`).
    public let name: String
    /// The content carried by this part.
    public let content: Content

    public enum Content {
        /// A plain UTF-8 text value.
        case text(String)
        /// In-memory binary data (e.g. an image already in memory).
        case data(Data, mimeType: String, filename: String)
        /// A file URL (data is read lazily by the upload stream).
        case fileURL(URL, mimeType: String?)
    }

    public init(name: String, _ content: Content) {
        self.name    = name
        self.content = content
    }
}

// MARK: - ParameterEncoding

/// Supported parameter encoding strategies.
public enum ParameterEncoding {
    case json
    case url
    /// Structured multipart/form-data. Parts are inspectable (used by the logger to emit cURL).
    case multipart([MultipartPart])
    /// Provide a closure that mutates the `URLRequest` directly (escape hatch for exotic encodings).
    case custom((inout URLRequest) throws -> Void)
}
