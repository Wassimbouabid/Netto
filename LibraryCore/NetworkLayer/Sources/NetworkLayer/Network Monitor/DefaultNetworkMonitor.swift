//
//  DefaultNetworkMonitor.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 27/12/2025.
//

import Foundation
import Network
internal import CocoaLumberjackSwift

/// Default implementation of the `NetworkMonitor` protocol.
///
/// This class monitors the device's network connectivity using `NWPathMonitor`
/// and provides real-time updates about connectivity changes.
final class DefaultNetworkMonitor: NetworkMonitor {
    /// The dispatch queue used for monitoring network changes.
    private let monitorQueue = DispatchQueue(label: "com.app.network.monitor", qos: .background)

    /// The path monitor used to track connectivity.
    private let pathMonitor = NWPathMonitor()

    /// Dictionary of handlers to be called when connectivity changes.
    private var connectivityHandlers: [UUID: (Bool) -> Void] = [:]

    /// Lock for thread-safe access to handlers.
    private let handlersLock = NSLock()

    /// Current connectivity status.
    private(set) var isConnected: Bool = false {
        didSet {
            if oldValue != isConnected {
                notifyHandlers()
            }
        }
    }

    /// Flag indicating whether monitoring is active.
    private var isMonitoring = false

    /// Initializes the network monitor.
    init() {
        setupMonitor()
    }

    deinit {
        stopMonitoring()
    }

    /// Starts monitoring network connectivity.
    ///
    /// If monitoring is already active, this method does nothing.
    func startMonitoring() {
        guard !isMonitoring else { return }
        pathMonitor.start(queue: monitorQueue)
        isMonitoring = true
    }

    /// Stops monitoring network connectivity.
    ///
    /// If monitoring is not active, this method does nothing.
    func stopMonitoring() {
        guard isMonitoring else { return }
        pathMonitor.cancel()
        isMonitoring = false
    }

    /// Registers a closure to be called when network connectivity changes.
    ///
    /// - Parameter handler: A closure to call when connectivity changes.
    /// - Returns: A token that can be used to unregister the handler.
    @discardableResult
    func onConnectivityChanged(_ handler: @escaping (Bool) -> Void) -> UUID {
        let token = UUID()
        handlersLock.lock()
        connectivityHandlers[token] = handler
        handlersLock.unlock()

        // immediately call the handler with the current status
        handler(isConnected)

        return token
    }

    /// Unregisters a previously registered connectivity handler.
    ///
    /// - Parameter token: The token returned by `onConnectivityChanged`.
    func removeHandler(with token: UUID) {
        handlersLock.lock()
        connectivityHandlers.removeValue(forKey: token)
        handlersLock.unlock()
    }
}

// MARK: - Private Methods

private extension DefaultNetworkMonitor {
    /// Sets up the network path monitor.
    func setupMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // update the connection status based on the path
            self.isConnected = path.status == .satisfied

            // log the connection type
            self.logConnectionType(path)
        }
    }

    /// Logs the current connection type for debugging purposes.
    ///
    /// - Parameter path: The network path to log.
    func logConnectionType(_ path: NWPath) {
        #if DEBUG
        if path.usesInterfaceType(.wifi) {
            DDLogVerbose("Network: Connected via WiFi")
        } else if path.usesInterfaceType(.cellular) {
            DDLogVerbose("Network: Connected via Cellular")
        } else if path.usesInterfaceType(.wiredEthernet) {
            DDLogVerbose("Network: Connected via Ethernet")
        } else if path.usesInterfaceType(.loopback) {
            DDLogVerbose("Network: Connected via Loopback")
        } else {
            DDLogVerbose("Network: Connected via unknown interface")
        }
        #endif
    }

    /// Notifies all registered handlers of connectivity changes.
    func notifyHandlers() {
        // take a snapshot of the handlers to avoid holding the lock during callback execution
        handlersLock.lock()
        let handlers = connectivityHandlers
        handlersLock.unlock()

        // notify on the main queue as handlers likely update UI
        DispatchQueue.main.async { [isConnected] in
            for (_, handler) in handlers {
                handler(isConnected)
            }
        }
    }
}
