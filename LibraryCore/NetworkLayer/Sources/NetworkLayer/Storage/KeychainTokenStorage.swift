//
//  KeychainTokenStorage.swift
//

import Foundation
import Security
internal import CocoaLumberjackSwift

// MARK: - Error

/// Errors thrown by `KeychainTokenStorage`.
public enum KeychainError: Error {
    /// A Keychain write operation failed with the given OS status code.
    case saveFailed(OSStatus)
}

// MARK: - Implementation

/// Default `TokenStorage` backed by the iOS Keychain.
///
/// All keys are namespaced under `keychainNamespace` so multiple apps (or
/// white-label variants) can coexist without key collisions.
///
/// **Usage:**
/// By default the namespace is derived from `Bundle.main.bundleIdentifier`.
/// Override it or provide a completely custom storage via
/// `NetworkContainer.shared.setTokenStorage(_:)`.
public final class KeychainTokenStorage: TokenStorage {

    // MARK: - Shared Instance

    /// Convenience singleton using the bundle ID as namespace.
    public static let shared = KeychainTokenStorage()

    // MARK: - Configuration

    private let keychainNamespace: String

    // MARK: - Initialisation

    /// Creates a storage instance with a custom namespace.
    ///
    /// - Parameter keychainNamespace: Prefix applied to every Keychain key.
    ///   Defaults to `Bundle.main.bundleIdentifier` (or `"NetworkLayer"` as a fallback).
    public init(keychainNamespace: String = Bundle.main.bundleIdentifier ?? "NetworkLayer") {
        self.keychainNamespace = keychainNamespace
    }

    // MARK: - Key Helpers

    private func key(for property: String) -> String {
        "\(keychainNamespace).\(property)"
    }

    private var accessTokenKey:  String { key(for: "accessToken") }
    private var refreshTokenKey: String { key(for: "refreshToken") }
    private var expiresAtKey:    String { key(for: "expiresAt") }
    private var refreshExpiresAtKey: String { key(for: "refreshExpiresAt") }
    private var installMarkerKey: String { key(for: "installMarker") }

    // MARK: - TokenStorage

    public var accessToken: String? {
        readKeychainValue(for: accessTokenKey)
    }

    public var refreshToken: String? {
        readKeychainValue(for: refreshTokenKey)
    }

    public var tokenExpiration: Date? {
        guard let raw = readKeychainValue(for: expiresAtKey),
              let interval = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public var isTokenExpired: Bool {
        guard let expiration = tokenExpiration else { return true }
        return Date() > expiration
    }

    public var refreshTokenExpiration: Date? {
        guard let raw = readKeychainValue(for: refreshExpiresAtKey),
              let interval = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public var isRefreshTokenExpired: Bool {
        guard let expiration = refreshTokenExpiration else { return true }
        return Date() > expiration
    }

    public func saveTokens(accessToken: String, refreshToken: String, expiresAt: Date?) throws {
        try saveKeychainValue(accessToken, for: accessTokenKey)
        try saveKeychainValue(refreshToken, for: refreshTokenKey)

        if let expiresAt {
            try saveKeychainValue("\(expiresAt.timeIntervalSince1970)", for: expiresAtKey)
        } else {
            deleteKeychainValue(for: expiresAtKey)
        }
    }

    public func saveRefreshTokenExpiration(_ expiresAt: Date?) throws {
        if let expiresAt {
            try saveKeychainValue("\(expiresAt.timeIntervalSince1970)", for: refreshExpiresAtKey)
        } else {
            deleteKeychainValue(for: refreshExpiresAtKey)
        }
    }

    public func clearTokens() {
        deleteKeychainValue(for: accessTokenKey)
        deleteKeychainValue(for: refreshTokenKey)
        deleteKeychainValue(for: expiresAtKey)
        deleteKeychainValue(for: refreshExpiresAtKey)
    }

    // MARK: - Reinstallation Guard

    /// Clears leftover Keychain data from a previous installation.
    ///
    /// iOS keeps Keychain items across uninstalls. Call this once at app launch
    /// (before reading any token) to detect a fresh install via the UserDefaults
    /// marker (which IS cleared on uninstall) and wipe stale tokens.
    public func handleReinstallation() {
        if !UserDefaults.standard.bool(forKey: installMarkerKey) {
            DDLogInfo("[KeychainTokenStorage] Fresh install detected — clearing stale keychain tokens")
            clearTokens()
            UserDefaults.standard.set(true, forKey: installMarkerKey)
        }
    }
}

// MARK: - Private Keychain Helpers

private extension KeychainTokenStorage {

    func readKeychainValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)

        guard status == errSecSuccess, let data = ref as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves `value` to the Keychain under `key`.
    ///
    /// - Throws: `KeychainError.saveFailed` when `SecItemAdd` returns a non-success status.
    func saveKeychainValue(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data
        ]

        // Remove any existing item first to avoid duplicate-item errors.
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            DDLogError("[KeychainTokenStorage] SecItemAdd failed for key '\(key)' — OSStatus: \(status)")
            throw KeychainError.saveFailed(status)
        }
    }

    func deleteKeychainValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
