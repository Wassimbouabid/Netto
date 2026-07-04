//
//  DefaultNetworkLogger.swift
//  NetworkLayer
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

    /// Initializes the logger with a specific configuration.
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

// MARK: - Private Methods

private extension DefaultNetworkLogger {
    /// Builds a cURL command string that reproduces the given request.
    ///
    /// Encoding-aware:
    /// - `.json`   → `Content-Type: application/json` + `-d '{"key":"value"}'`
    /// - `.url`    → `Content-Type: application/x-www-form-urlencoded` + `--data-urlencode "key=value"` per pair
    /// - `.custom` → body omitted with a note (closure cannot be serialised)
    ///
    /// Sensitive headers and parameters are redacted using the same rules
    /// applied to the rest of the log output.
    func curlCommand(for request: APIRequest) -> String {
        var parts = ["curl -v"]

        // Method (omit -X GET since it's curl's default)
        if request.method != .get {
            parts.append("-X \(request.method.rawValue)")
        }

        // Explicit headers from the request.
        // Content-Type is injected below (per encoding) only if the caller hasn't already set it.
        let existingHeaders = request.headers ?? [:]
        let hasContentType  = existingHeaders.keys.contains { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }

        for (key, value) in existingHeaders.sorted(by: { $0.key < $1.key }) {
            let displayValue = shouldRedactHeader(key) ? redactionText : value
            parts.append("-H \"\(key): \(displayValue)\"")
        }

        // Body — encoding-aware; omitted for GET requests
        if request.method != .get {
            let sanitized = sanitizeParameters(request.parameters ?? [:])

            switch request.encoding {
            case .json:
                if !hasContentType {
                    parts.append("-H \"Content-Type: application/json\"")
                }
                if let data = try? JSONSerialization.data(withJSONObject: sanitized),
                   let body = String(data: data, encoding: .utf8) {
                    let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
                    parts.append("-d '\(escaped)'")
                }

            case .url:
                if !hasContentType {
                    parts.append("-H \"Content-Type: application/x-www-form-urlencoded\"")
                }
                // One --data-urlencode per key=value pair — handles special characters correctly
                for (key, value) in sanitized.sorted(by: { $0.key < $1.key }) {
                    let displayValue = shouldRedactParameter(key) ? redactionText : "\(value)"
                    parts.append("--data-urlencode \"\(key)=\(displayValue)\"")
                }

            case .multipart(let multipartParts):
                if !hasContentType {
                    parts.append("-H \"Content-Type: multipart/form-data\"")
                }
                for part in multipartParts {
                    switch part.content {
                    case .text(let value):
                        let displayValue = shouldRedactParameter(part.name) ? redactionText : value
                        parts.append("-F \"\(part.name)=\(displayValue)\"")
                    case .data(_, let mimeType, let filename):
                        parts.append("-F \"\(part.name)=@\(filename);type=\(mimeType)\"")
                    case .fileURL(let url, let mimeType):
                        let typeAnnotation = mimeType.map { ";type=\($0)" } ?? ""
                        parts.append("-F \"\(part.name)=@\(url.path)\(typeAnnotation)\"")
                    }
                }

            case .custom:
                parts.append("# body omitted — .custom encoding cannot be serialised")
            }
        }

        // URL — always last
        parts.append("\"\(request.url)\"")

        return parts.joined(separator: " \\\n  ")
    }

    /// Determines if a header should be redacted in logs.
    ///
    /// - Parameter key: The header key to check.
    /// - Returns: `true` if the header should be redacted, `false` otherwise.
    func shouldRedactHeader(_ key: String) -> Bool {
        guard !includeSensitiveData else { return false }
        return sensitiveHeaders.contains { key.caseInsensitiveCompare($0) == .orderedSame }
    }

    /// Determines if a parameter should be redacted in logs.
    ///
    /// - Parameter key: The parameter key to check.
    /// - Returns: `true` if the parameter should be redacted, `false` otherwise.
    func shouldRedactParameter(_ key: String) -> Bool {
        guard !includeSensitiveData else { return false }
        // check if key contains or equals any sensitive parameter
        return sensitiveParameters.contains {
            key.caseInsensitiveCompare($0) == .orderedSame ||
            key.lowercased().contains($0.lowercased())
        }
    }

    /// Sanitizes parameters to redact sensitive information.
    ///
    /// - Parameter parameters: The original parameters.
    /// - Returns: A sanitized copy with sensitive data redacted.
    func sanitizeParameters(_ parameters: [String: Any]) -> [String: Any] {
        guard !includeSensitiveData else { return parameters }
        var sanitized = [String: Any]()
        for (key, value) in parameters {
            if shouldRedactParameter(key) {
                sanitized[key] = redactionText
            } else if let nestedDict = value as? [String: Any] {
                // recursively sanitize nested dictionaries
                sanitized[key] = sanitizeParameters(nestedDict)
            } else if let nestedArray = value as? [Any] {
                // recursively sanitize array values
                sanitized[key] = sanitizeArray(nestedArray)
            } else {
                sanitized[key] = value
            }
        }

        return sanitized
    }

    /// Sanitizes an array to redact sensitive information.
    ///
    /// - Parameter array: The original array.
    /// - Returns: A sanitized copy with sensitive data redacted.
    func sanitizeArray(_ array: [Any]) -> [Any] {
        guard !includeSensitiveData else { return array }
        return array.map { value in
            if let dict = value as? [String: Any] {
                return sanitizeParameters(dict)
            } else if let nestedArray = value as? [Any] {
                return sanitizeArray(nestedArray)
            } else {
                return value
            }
        }
    }

    /// Sanitizes response JSON to redact sensitive information.
    ///
    /// - Parameter json: The original JSON object.
    /// - Returns: A sanitized copy with sensitive data redacted.
    func sanitizeResponseJson(_ json: Any) -> Any {
        guard !includeSensitiveData else { return json }

        if let dict = json as? [String: Any] {
            var sanitized = [String: Any]()

            for (key, value) in dict {
                let lowercaseKey = key.lowercased()

                // check if this key is in our sensitive list
                let shouldRedact = sensitiveResponseFields.contains {
                    lowercaseKey == $0.lowercased() ||
                    lowercaseKey.contains($0.lowercased())
                }

                // handle specific nested objects that may contain PII even if the key isn't sensitive
                let isPotentialUserProfile = (lowercaseKey.contains("user") ||
                                            lowercaseKey.contains("profile") ||
                                            lowercaseKey.contains("customer") ||
                                            lowercaseKey.contains("account") ||
                                            lowercaseKey.contains("personal"))

                if shouldRedact {
                    // redact sensitive fields
                    sanitized[key] = redactionText
                } else if lowercaseKey == "api_customer" || lowercaseKey == "user" || lowercaseKey == "profile" {
                    // special case for user/customer objects - preserve structure but redact sensitive fields
                    if let nestedDict = value as? [String: Any] {
                        sanitized[key] = sanitizeUserObject(nestedDict)
                    } else {
                        sanitized[key] = value
                    }
                } else if let nestedDict = value as? [String: Any] {
                    // recursively sanitize nested dictionaries
                    sanitized[key] = sanitizeResponseJson(nestedDict)
                } else if let nestedArray = value as? [Any] {
                    // recursively sanitize arrays
                    sanitized[key] = sanitizeResponseJson(nestedArray)
                } else if let stringValue = value as? String, isPotentialUserProfile, stringValue.count > 3 {
                    // if this field is within a user/profile/customer object and looks like PII
                    if isProbablyPersonalData(stringValue) {
                        sanitized[key] = redactionText
                    } else {
                        sanitized[key] = value
                    }
                } else {
                    sanitized[key] = value
                }
            }

            return sanitized
        } else if let array = json as? [Any] {
            return array.map { sanitizeResponseJson($0) }
        }

        return json
    }

    /// Specially sanitizes user/customer objects to ensure PII is protected.
    ///
    /// - Parameter userObject: A dictionary representing a user or customer object.
    /// - Returns: Sanitized object with personal information redacted.
    func sanitizeUserObject(_ userObject: [String: Any]) -> [String: Any] {
        var sanitized = [String: Any]()

        // fields in user objects that should always be preserved
        let safeFields = ["is_admin", "is_notifications_push", "is_notifications_email",
                         "is_use_imperial_units", "settings", "use_imperial_units",
                         "notifications_push", "notifications_email", "language", "api_language"]

        for (key, value) in userObject {
            let lowercaseKey = key.lowercased()

            if safeFields.contains(where: { $0.lowercased() == lowercaseKey }) {
                // safe fields are preserved
                sanitized[key] = value
            } else if lowercaseKey.contains("id") && (value is Int || value is String) {
                // iDs should be redacted
                sanitized[key] = redactionText
            } else if let nestedDict = value as? [String: Any] {
                // recursively sanitize nested objects
                sanitized[key] = sanitizeResponseJson(nestedDict)
            } else if let nestedArray = value as? [Any] {
                sanitized[key] = sanitizeResponseJson(nestedArray)
            } else if let stringValue = value as? String, stringValue.count > 3 {
                // redact anything that looks like personal data
                if isProbablyPersonalData(stringValue) {
                    sanitized[key] = redactionText
                } else {
                    sanitized[key] = value
                }
            } else {
                // for numeric values or other types, preserve
                sanitized[key] = value
            }
        }
        return sanitized
    }

    /// Attempts to determine if a string value is likely personal data.
    ///
    /// - Parameter value: The string to check.
    /// - Returns: True if the string appears to be personal data.
    func isProbablyPersonalData(_ value: String) -> Bool {
        // check for email patterns
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if value.range(of: emailPattern, options: .regularExpression) != nil {
            return true
        }

        // check for name patterns (capitalized words)
        let namePattern = "^[A-Z][a-z]+$"
        if value.range(of: namePattern, options: .regularExpression) != nil && value.count > 2 {
            return true
        }

        // check for username patterns
        if value.contains("-") || value.contains("_") || value.hasPrefix("user") {
            return true
        }

        // check for phone number patterns
        let digitCount = value.filter { $0.isNumber }.count
        if digitCount > 5 && digitCount == value.filter({ $0.isNumber || $0 == "+" || $0 == "-" || $0 == " " || $0 == "(" || $0 == ")" }).count {
            return true
        }

        return false
    }

    /// Sanitizes a response string to redact sensitive information.
    ///
    /// - Parameter string: The original response string.
    /// - Returns: A sanitized string with sensitive data redacted.
    private func sanitizeResponseString(_ string: String) -> String {
        guard !includeSensitiveData else { return string }
        var result = string

        // replace sensitive fields using regular expressions
        for field in sensitiveResponseFields {
            // match patterns like "access_token": "abc123"
            let pattern1 = "\"(\(field))\"\\s*:\\s*\"([^\"]*)\""
            result = result.replacingOccurrences(
                of: pattern1,
                with: "\"$1\": \"\(redactionText)\"",
                options: .regularExpression
            )

            // match patterns like access_token=abc123
            let pattern2 = "(\(field))=([^&\\s]*)"
            result = result.replacingOccurrences(
                of: pattern2,
                with: "$1=\(redactionText)",
                options: .regularExpression
            )
        }

        return result
    }

    /// Sanitizes a value for logging.
    ///
    /// - Parameter value: The value to sanitize.
    /// - Returns: A sanitized version of the value.
    func sanitizeValue(_ value: Any) -> Any {
        guard !includeSensitiveData else { return value }

        if let string = value as? String {
            // check if the string looks like a token
            if string.count > 20 ||
               string.contains("token") ||
               string.contains("bearer") {
                return redactionText
            }
            return sanitizeResponseString(string)
        } else if let dict = value as? [String: Any] {
            return sanitizeParameters(dict)
        } else if let array = value as? [Any] {
            return sanitizeArray(array)
        }

        return value
    }
}
