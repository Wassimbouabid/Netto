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

// MARK: - APIRequest

/// A fully-prepared network request, built from an `APIEndpoint` plus the base URL.
///
/// Passed directly to `NetworkLogger` methods so custom loggers have access to the
/// complete request context (method, URL, headers, parameters, timeout, encoding).
public struct APIRequest {
    public let url: String
    public let method: HTTPMethod
    public let parameters: [String: Any]?
    public let encoding: ParameterEncoding
    public var headers: [String: String]?
    public let timeout: TimeInterval?

    public init(endpoint: any APIEndpoint, baseURL: URL) {
        let base = baseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = endpoint.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        self.url        = "\(base)/\(path)"
        self.method     = endpoint.method
        self.parameters = endpoint.parameters
        self.encoding   = endpoint.encoding
        self.headers    = endpoint.headers
        self.timeout    = endpoint.timeout
    }

    /// Creates a minimal GET request from a fully-qualified URL string.
    ///
    /// Used by `MediaDownloadServiceImpl` to pass a media URL through the
    /// `PreRequestHandler` pipeline (e.g. to attach an `Authorization` header)
    /// without requiring an `APIEndpoint` or a base-URL split.
    public init(rawURL: String) {
        self.url        = rawURL
        self.method     = .get
        self.parameters = nil
        self.encoding   = .url
        self.headers    = nil
        self.timeout    = nil
    }

}
