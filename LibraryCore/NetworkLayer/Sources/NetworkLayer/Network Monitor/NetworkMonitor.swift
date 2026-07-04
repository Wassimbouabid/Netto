//
//  NetworkMonitor.swift
//  NetworkLayer
//
//  Created by Bouabid Wassim on 27/12/2025.
//

import Foundation

/// Monitors network connectivity status.
///
/// NetworkMonitor is responsible for tracking the network connection status
/// and notifying the app when connectivity changes.
public protocol NetworkMonitor {
    /// The current network connectivity status.
    var isConnected: Bool { get }

    /// Starts monitoring network connectivity.
    func startMonitoring()

    /// Stops monitoring network connectivity.
    func stopMonitoring()

    /// Registers a closure to be called when network connectivity changes.
    ///
    /// - Parameter handler: A closure to call when connectivity changes.
    /// - Returns: A token that can be used to unregister the handler.
    @discardableResult
    func onConnectivityChanged(_ handler: @escaping (Bool) -> Void) -> UUID

    /// Unregisters a previously registered connectivity handler.
    ///
    /// - Parameter token: The token returned by `onConnectivityChanged`.
    func removeHandler(with token: UUID)
}
