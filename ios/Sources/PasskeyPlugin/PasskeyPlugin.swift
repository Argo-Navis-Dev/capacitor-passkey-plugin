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
            missingParamCode: PasskeyPluginErrorCode.missingPublicKeyCreate,
            jsonErrorCode: PasskeyPluginErrorCode.jsonSerializationCreate
        ) else { return }

        Task {
            do {
                let result = try await implementation.createPasskey(publicKeyData)
                call.resolve(result)
            } catch {
                let errorMsg = error.localizedDescription
                print("[PasskeyPlugin] Passkey creation failed: \(errorMsg)")
                call.reject(
                    errorMsg,
                    PasskeyPluginErrorCode.passkeyCreationFailed.rawValue,
                    PasskeyPluginStringError(
                        message: "passkey_creation_failed",
                        descriptionText: "Passkey creation failed: \(errorMsg)"
                    )
                )
            }
        }
    }

    /// Authenticate with a passkey. Expects `publicKey` param as [String: Any].
    @objc func authenticate(_ call: CAPPluginCall) {
        guard let publicKeyData = extractPublicKeyData(
            from: call,
            missingParamCode: PasskeyPluginErrorCode.missingPublicKeyAuth,
            jsonErrorCode: PasskeyPluginErrorCode.jsonSerializationAuth
        ) else { return }

        Task {
            do {
                let result = try await implementation.authenticate(publicKeyData)
                call.resolve(result)
            } catch {
                let errorMsg = error.localizedDescription
                print("[PasskeyPlugin] Passkey authentication failed: \(errorMsg)")
                call.reject(
                    errorMsg,
                    PasskeyPluginErrorCode.passkeyAuthFailed.rawValue,
                    PasskeyPluginStringError(
                        message: "passkey_authentication_failed",
                        descriptionText: "Passkey authentication failed: \(errorMsg)"
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
}
