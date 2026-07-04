//
//  ConnectivityListener.swift
//

import Foundation

/// Bridges connectivity changes to the presentation layer.
///
/// Implement this protocol in the UI layer (e.g. an `AppCoordinator`,
/// a root `ViewModel`, or a SwiftUI `EnvironmentObject`) to present
/// or dismiss a "no internet" indicator automatically.
///
/// Both methods are called on the **main thread** so you can update
/// the UI directly without dispatching.
///
/// ## Usage
/// ```swift
/// final class AppConnectivityHandler: ConnectivityListener {
///     func onConnectionLost() {
///         // present a banner / overlay
///     }
///     func onConnectionRestored() {
///         // dismiss the banner
///     }
/// }
///
/// NetworkServiceBuilder(configuration: config)
///     .withConnectivityListener(AppConnectivityHandler())
///     .build()
/// ```
public protocol ConnectivityListener: AnyObject {
    /// Called when the device loses network connectivity.
    func onConnectionLost()

    /// Called when the device regains network connectivity.
    func onConnectionRestored()
}
