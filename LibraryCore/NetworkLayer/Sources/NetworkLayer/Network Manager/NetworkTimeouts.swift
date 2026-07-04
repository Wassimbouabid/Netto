//
//  NetworkTimeouts.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 24/12/2025.
//

import Foundation

/// Network timeout values based on mobile best practices
///
/// **Industry Standards:**
/// - AWS API Gateway: 29s default
/// - iOS URLSession: 60s default
/// - User attention: 5-10s before feedback needed
/// - Mobile apps: 10-30s typical
public enum NetworkTimeouts {

    /// Connection timeout: 10 seconds
    ///
    /// Time allowed to establish TCP connection.
    /// Based on RTT × 3 rule for mobile networks.
    public static let connection: TimeInterval = 10

    /// Standard request: 30 seconds
    ///
    /// Used for most API operations (GET/POST/PUT/DELETE).
    /// Resets when data arrives.
    ///
    /// **Industry standard for mobile-to-server communication.**
    public static let standard: TimeInterval = 30

    /// Quick operations: 15 seconds
    ///
    /// Used for fast operations like auth and validation.
    public static let quick: TimeInterval = 15

    /// File operations: 60 seconds
    ///
    /// Used for image uploads and file downloads.
    public static let fileOperation: TimeInterval = 60

    /// Resource timeout: 5 minutes
    ///
    /// Absolute maximum time for entire operation.
    /// Prevents infinite hangs on slow operations.
    public static let resource: TimeInterval = 300
}
