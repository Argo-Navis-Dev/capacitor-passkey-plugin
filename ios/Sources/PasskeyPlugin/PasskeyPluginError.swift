// PasskeyPluginError.swift

import Foundation

@available(iOS 15.0, *)
public enum PasskeyPluginErrorCode: String {
    // Standardized error codes matching Web and Android
    case unknown = "UNKNOWN_ERROR"
    case cancelled = "CANCELLED"
    case domError = "DOM_ERROR"
    case unsupported = "UNSUPPORTED_ERROR"
    case timeout = "TIMEOUT"
    case noCredential = "NO_CREDENTIAL"
    case invalidInput = "INVALID_INPUT"
    case rpIdValidation = "RPID_VALIDATION_ERROR"
}

// Optional: If you want to share the StringError struct as well
public struct PasskeyPluginStringError: Error, LocalizedError {
    public let message: String
    public let descriptionText: String

    public var errorDescription: String? {
        return descriptionText
    }
}
