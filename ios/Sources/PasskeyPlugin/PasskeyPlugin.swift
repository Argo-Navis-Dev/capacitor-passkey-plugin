import Foundation
import Capacitor
import AuthenticationServices

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
    
    /// Maps errors to standardized error codes using type-safe enum matching
    private func mapNSErrorToStandardCode(_ error: Error) -> String {
        let nsError = error as NSError

        // Check for our custom error domains first
        switch nsError.domain {
        case "PasskeyTimeout":
            return PasskeyPluginErrorCode.timeout.rawValue
        case "PasskeyValidation":
            return PasskeyPluginErrorCode.rpIdValidation.rawValue
        case "PasskeyDelegate":
            return PasskeyPluginErrorCode.unsupported.rawValue
        default:
            break
        }

        // Check for ASAuthorizationError using proper enum matching
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return PasskeyPluginErrorCode.cancelled.rawValue
            case .invalidResponse:
                return PasskeyPluginErrorCode.domError.rawValue
            case .notHandled:
                return PasskeyPluginErrorCode.noCredential.rawValue
            case .failed:
                return PasskeyPluginErrorCode.unknown.rawValue
            case .notInteractive:
                return PasskeyPluginErrorCode.unsupported.rawValue
            case .matchedExcludedCredential:
                return PasskeyPluginErrorCode.invalidInput.rawValue
            case .unknown:
                return PasskeyPluginErrorCode.unknown.rawValue
            case .credentialImport:
                return PasskeyPluginErrorCode.invalidInput.rawValue
            case .credentialExport:
                return PasskeyPluginErrorCode.invalidInput.rawValue
            case .preferSignInWithApple:
                return PasskeyPluginErrorCode.unsupported.rawValue
            case .deviceNotConfiguredForPasskeyCreation:
                return PasskeyPluginErrorCode.unsupported.rawValue
            @unknown default:
                return PasskeyPluginErrorCode.unknown.rawValue
            }
        }

        // Fallback for truly unknown errors
        return PasskeyPluginErrorCode.unknown.rawValue
    }
}
