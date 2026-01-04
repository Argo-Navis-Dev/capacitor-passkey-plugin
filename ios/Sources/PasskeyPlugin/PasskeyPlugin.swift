import Foundation
import Capacitor

/**
 * PasskeyPlugin: Capacitor iOS plugin entry point for passkey registration and authentication.
 * Handles method calls from JS, parameter extraction, error reporting, and result delivery.
 */

@available(iOS 15.0, *)
@objc(PasskeyPlugin)
public class PasskeyPlugin: CAPPlugin, CAPBridgedPlugin {

    public let identifier = "PasskeyPlugin"
    public let jsName = "PasskeyPlugin"

    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createPasskey", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authenticate", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = PasskeyPluginImpl()


    /// Register a new passkey. Expects `publicKey` param as [String: Any].
    @objc func createPasskey(_ call: CAPPluginCall) {
        guard let publicKeyData = extractPublicKeyData(
            from: call,
            missingParamCode: PasskeyPluginErrorCode.invalidInput,
            jsonErrorCode: PasskeyPluginErrorCode.invalidInput
        ) else { return }

        Task {
            do {
                let result = try await implementation.createPasskey(publicKeyData)
                call.resolve(result)
            } catch {
                let errorMsg = error.localizedDescription
                let errorCode = mapNSErrorToStandardCode(error)
                
                call.reject(
                    errorMsg,
                    errorCode,
                    PasskeyPluginStringError(
                        message: "passkey_creation_failed",
                        descriptionText: errorMsg
                    )
                )
            }
        }
    }

    /// Authenticate with a passkey. Expects `publicKey` param as [String: Any].
    @objc func authenticate(_ call: CAPPluginCall) {
        guard let publicKeyData = extractPublicKeyData(
            from: call,
            missingParamCode: PasskeyPluginErrorCode.invalidInput,
            jsonErrorCode: PasskeyPluginErrorCode.invalidInput
        ) else { return }

        Task {
            do {
                let result = try await implementation.authenticate(publicKeyData)
                call.resolve(result)
            } catch {
                let errorMsg = error.localizedDescription
                let errorCode = mapNSErrorToStandardCode(error)                
                call.reject(
                    errorMsg,
                    errorCode,
                    PasskeyPluginStringError(
                        message: "passkey_authentication_failed",
                        descriptionText: errorMsg
                    )
                )
            }
        }
    }


    /// Extracts and serializes the `publicKey` param from the CAPPluginCall.
    /// Returns nil and rejects the call if missing or serialization fails.
    private func extractPublicKeyData(
        from call: CAPPluginCall,
        missingParamCode: PasskeyPluginErrorCode,
        jsonErrorCode: PasskeyPluginErrorCode
    ) -> Data? {
        guard let publicKey = call.getObject("publicKey") as? [String: Any] else {
            call.reject(
                "Missing or invalid 'publicKey' parameter.",
                missingParamCode.rawValue,
                PasskeyPluginStringError(
                    message: "invalid_public_key_param",
                    descriptionText: "The 'publicKey' parameter is missing or malformed."
                )
            )
            return nil
        }

        guard let publicKeyData = try? JSONSerialization.data(withJSONObject: publicKey) else {
            call.reject(
                "Unable to serialize 'publicKey' to JSON.",
                jsonErrorCode.rawValue,
                PasskeyPluginStringError (
                    message: "json_serialization_failed",
                    descriptionText: "Failed to convert the publicKey object to valid JSON format."
                )
            )
            return nil
        }

        return publicKeyData
    }
    
    /// Maps NSError and specific error types to standardized error codes
    private func mapNSErrorToStandardCode(_ error: Error) -> String {
        let nsError = error as NSError
        
        // Check for specific error domains and codes
        switch nsError.domain {
        case "PasskeyTimeout":
            return PasskeyPluginErrorCode.timeout.rawValue
        case "PasskeyValidation":
            return PasskeyPluginErrorCode.rpIdValidation.rawValue
        case "ASAuthorizationError":
            switch nsError.code {
            case 1001: // ASAuthorizationError.Code.canceled
                return PasskeyPluginErrorCode.cancelled.rawValue
            case 1004: // ASAuthorizationError.Code.notHandled
                return PasskeyPluginErrorCode.noCredential.rawValue
            default:
                return PasskeyPluginErrorCode.unknown.rawValue
            }
        default:
            // Check error message for common patterns
            let errorMsg = nsError.localizedDescription.lowercased()
            if errorMsg.contains("cancel") || errorMsg.contains("user") {
                return PasskeyPluginErrorCode.cancelled.rawValue
            } else if errorMsg.contains("timeout") {
                return PasskeyPluginErrorCode.timeout.rawValue
            } else if errorMsg.contains("unsupported") || errorMsg.contains("not supported") {
                return PasskeyPluginErrorCode.unsupported.rawValue
            } else if errorMsg.contains("credential") && errorMsg.contains("not found") {
                return PasskeyPluginErrorCode.noCredential.rawValue
            } else {
                return PasskeyPluginErrorCode.unknown.rawValue
            }
        }
    }
}
