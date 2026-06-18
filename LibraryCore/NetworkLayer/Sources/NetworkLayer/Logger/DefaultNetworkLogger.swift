//
//  DefaultNetworkLogger.swift
//  RevampCarSharing
//
//  Created by Bouabid Wassim on 28/12/2025.
//


import Foundation
internal import CocoaLumberjackSwift

/// Default implementation of the `NetworkLogger` protocol using CocoaLumberjack.
///
/// This class focuses solely on formatting and logging network-related events
/// using the CocoaLumberjack framework while protecting sensitive data.
final class DefaultNetworkLogger: NetworkLogger {
    /// Log level for controlling verbosity.
    enum LogLevel: Int, Comparable {
        case none = 0
        case basic = 1
        case headers = 2
        case body = 3
        case full = 4

        /// Implements Comparable protocol for LogLevel enum
        static func < (lhs: DefaultNetworkLogger.LogLevel, rhs: DefaultNetworkLogger.LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    /// The current log level.
    private let logLevel: LogLevel

    /// Whether to log sensitive information.
    private let includeSensitiveData: Bool

    /// Text to use when redacting sensitive information.
    private let redactionText = "****REDACTED****"

    /// List of header keys considered sensitive.
    private let sensitiveHeaders = [
        "Authorization",
        "X-API-Key",
        "Cookie",
        "Set-Cookie",
        "x-auth-token",
        "access-token",
        "refresh-token"
    ]

    /// List of parameter keys considered sensitive.
    private let sensitiveParameters = [
        "password",
        "new_password",
        "old_password",
        "current_password",
        "secret",
        "token",
        "access_token",
        "refresh_token",
        "pin",
        "passcode",
        "security_code",
        "credit_card",
        "card_number",
        "cvv",
        "ssn"
    ]

    /// List of response fields considered sensitive.
    private let sensitiveResponseFields = [
        // Authentication data
        "access_token",
        "accessToken",
        "refresh_token",
        "refreshToken",
        "token",
        "password",
        "secret",
        "credentials",

        // Personal information
        "email",
        "username",
        "user_name",
        "firstname",
        "first_name",
        "lastname",
        "last_name",
        "fullname",
        "full_name",
        "telephone",
        "phone",
        "phone_number",
        "mobile",
        "ssn",
        "social_security",
        "dob",
        "date_of_birth",
        "birth_date",

        // Location data
        "latitude",
        "longitude",
        "lat",
        "lng",
        "coordinates",
        "street",
        "address",
        "postal_code",
        "zip",

        // Identifiers
        "id",
        "user_id",
        "customer_id",
        "account_id"
    ]

    /// Initializes the log3KBT with a specific configuration.
    ///
    /// - Parameters:
    ///   - logLevel: The level of detail to include in logs (default: `.full`).
    ///   - includeSensitiveData: Whether to log sensitive information (default: `false`).
    init(logLevel: LogLevel = .full, includeSensitiveData: Bool = false) {
        // Guard against duplicate registration when the logger is recreated
        // (e.g. during DI container resets or unit tests).
        DDLog.add(DDOSLogger.sharedInstance)
        self.logLevel = logLevel
        self.includeSensitiveData = includeSensitiveData
    }

    /// Logs a network request that is about to be sent.
    ///
    /// - Parameter request: The request to log.
    func logRequest(_ request: APIRequest) {
        guard logLevel != .none else { return }

        var logComponents = ["➡️ [REQUEST] \(request.method.rawValue) \(request.url)"]

        if logLevel >= .headers, let headers = request.headers {
            logComponents.append("\nHeaders:")
            for (key, value) in headers {
                let displayValue = shouldRedactHeader(key) ? redactionText : value
                logComponents.append("  \(key): \(displayValue)")
            }
        }

        if logLevel >= .body, let parameters = request.parameters, !parameters.isEmpty {
            logComponents.append("\nParameters:")

            // Create a sanitized copy of parameters with sensitive data redacted
            let sanitizedParams = sanitizeParameters(parameters)

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: sanitizedParams, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logComponents.append(jsonString)
                }
            } catch {
                logComponents.append("  Unable to serialize parameters: \(error)")
            }
        }

        if logLevel >= .full {
            logComponents.append("\n\(curlCommand(for: request))")
        }

        DDLogDebug("\(logComponents.joined(separator: "\n"))")
    }

    /// Logs a successful network response.
    ///
    /// - Parameters:
    ///   - data: The response data.
    ///   - response: The HTTP response.
    ///   - request: The original request.
    ///   - duration: The time taken to complete the request.
    func logResponse(_ data: Data?, response: HTTPURLResponse?, for request: APIRequest, duration: TimeInterval) {
        guard logLevel != .none else { return }

        var logComponents = ["⬅️ [RESPONSE] \(request.method.rawValue) \(request.url)"]

        if let statusCode = response?.statusCode {
            let statusSymbol = (200...299).contains(statusCode) ? "✅" : "⚠️"
            logComponents[0] += " \(statusSymbol) (\(statusCode)) in \(String(format: "%.3f", duration))s"
        }

        if logLevel >= .headers, let headers = response?.allHeaderFields as? [String: Any] {
            logComponents.append("\nHeaders:")
            for (key, value) in headers {
                let keyString = String(describing: key)
                let displayValue = shouldRedactHeader(keyString) ? redactionText : String(describing: value)
                logComponents.append("  \(keyString): \(displayValue)")
            }
        }

        if logLevel >= .body, let data = data, !data.isEmpty {
            logComponents.append("\nBody:")

            // Try to parse as JSON and sanitize sensitive data
            if let json = try? JSONSerialization.jsonObject(with: data) {
                let sanitizedJson = sanitizeResponseJson(json)
                if let prettyData = try? JSONSerialization.data(withJSONObject: sanitizedJson, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    logComponents.append(prettyString)
                } else {
                    logComponents.append("  [Unable to format JSON]")
                }
            } else if let string = String(data: data, encoding: .utf8) {
                // For non-JSON responses, try basic redaction
                let sanitizedString = sanitizeResponseString(string)
                logComponents.append(sanitizedString)
            } else {
                logComponents.append("  [Binary data: \(data.count) bytes]")
            }
        }

        // Use appropriate log level based on status code
        let message = logComponents.joined(separator: "\n")
        if response?.statusCode ?? 0 >= 400 {
            DDLogWarn("\(message)")
        } else {
            DDLogInfo("\(message)")
        }
    }

    /// Logs a network error.
    ///
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - request: The request that failed.
    ///   - duration: The time taken before the error occurred.
    func logError(_ error: Error, for request: APIRequest, duration: TimeInterval) {
        guard logLevel != .none else { return }

        var logComponents = ["❌ [ERROR] \(request.method.rawValue) \(request.url) in \(String(format: "%.3f", duration))s"]

        if let networkError = error as? NetworkError {
            logComponents.append("NetworkError: \(networkError.localizedDescription)")

            if logLevel >= .full, let statusCode = networkError.statusCode {
                logComponents.append("Status Code: \(statusCode)")
            }

            if logLevel >= .full {
                // Sanitize debug description in case it contains sensitive info
                let sanitizedDebug = sanitizeResponseString(String(describing: networkError))
                logComponents.append("Debug Info: \(sanitizedDebug)")
            }
        } else {
            logComponents.append("Error: \(error.localizedDescription)")

            if logLevel >= .full {
                logComponents.append("Error Type: \(type(of: error))")

                let nsError = error as NSError
                logComponents.append("Domain: \(nsError.domain)")
                logComponents.append("Code: \(nsError.code)")

                if !nsError.userInfo.isEmpty {
                    logComponents.append("UserInfo:")
                    for (key, value) in nsError.userInfo {
                        // Sanitize user info values
                        let sanitizedValue = sanitizeValue(value)
                        logComponents.append("  \(key): \(sanitizedValue)")
                    }
                }
            }
        }

        // Log the error with string interpolation
        DDLogError("\(logComponents.joined(separator: "\n"))")
    }
}
