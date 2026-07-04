//
//  MediaDownloadResult.swift
//  Netto
//
//  Created by Bouabid Wassim on 30/12/2025.
//

import Foundation

/// Result of a media download operation
public enum MediaDownloadResult {
    case success(data: Data)
    case failure(error: Error)
}
