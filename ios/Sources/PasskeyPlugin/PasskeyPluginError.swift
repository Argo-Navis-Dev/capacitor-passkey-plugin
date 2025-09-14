// PasskeyPluginError.swift

import Foundation

@available(iOS 15.0, *)
public enum PasskeyPluginErrorCode: String {
    // CreatePasskey errors
    case missingPublicKeyCreate = "-100"
    case jsonSerializationCreate = "-101"
    case passkeyCreationFailed = "-102"
    // Authenticate errors
    case missingPublicKeyAuth = "-200"
    case jsonSerializationAuth = "-201"
    case passkeyAuthFailed = "-202"
    // General
    case unsupportedCredentialType = "-300"
}

// Optional: If you want to share the StringError struct as well
public struct PasskeyPluginStringError: Error, LocalizedError {
    public let message: String
    public let descriptionText: String

    public var errorDescription: String? {
        return descriptionText
    }
}
