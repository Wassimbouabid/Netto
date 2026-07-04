//
//  MediaDownloadService.swift
//  Netto
//
//  Created by Bouabid Wassim on 30/12/2025.
//

/// Generic protocol for downloading media files.
///
/// Obtain a conforming instance via `MediaServiceBuilder`:
/// ```swift
/// let mediaService = MediaServiceBuilder(configuration: config).build()
/// ```
public protocol MediaDownloadService {
    func downloadMedia(_ request: MediaDownloadRequest) async -> MediaDownloadResult
    func downloadMultipleMedia(_ requests: [MediaDownloadRequest]) async -> [MediaDownloadRequest: MediaDownloadResult]
}
