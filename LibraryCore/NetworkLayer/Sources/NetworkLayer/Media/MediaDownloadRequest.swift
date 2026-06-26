//
//  MediaDownloadRequest.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 30/12/2025.
//

/// Generic media download request
public struct MediaDownloadRequest: Hashable {
    public let id: String
    public let url: String
    public let maxRetryAttempts: Int
    public let metadata: [String: Any]?

    public init(id: String, url: String, maxRetryAttempts: Int = 2, metadata: [String: Any]? = nil) {
        self.id = id
        self.url = url
        self.maxRetryAttempts = maxRetryAttempts
        self.metadata = metadata
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }

    public static func == (lhs: MediaDownloadRequest, rhs: MediaDownloadRequest) -> Bool {
        return lhs.id == rhs.id && lhs.url == rhs.url
    }
}
