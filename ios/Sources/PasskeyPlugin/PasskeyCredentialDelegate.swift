import Foundation
import AuthenticationServices
import UIKit

@available(iOS 15.0, *)
@MainActor
class PasskeyCredentialDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    typealias ResultData = Result<[String: Any], Error>
    var completion: ((ResultData) -> Void)?
    private var timeoutTimer: Timer?
    private var hasCompleted = false

    /// Thread-safe method to call completion exactly once, preventing race conditions
    /// between timeout and authorization callbacks.
    private func completeOnce(with result: ResultData) {
        guard !hasCompleted else { return }
        hasCompleted = true
        cleanupTimer()
        completion?(result)
        completion = nil
    }

    // Called when passkey creation/authentication succeeds
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let credential as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            let id = credential.credentialID.toBase64URLEncoded()
            let rawId = credential.credentialID.toBase64URLEncoded()
            let type = "public-key"
            let clientDataJSON = credential.rawClientDataJSON.toBase64URLEncoded()
            let attestationObject = credential.rawAttestationObject?.toBase64URLEncoded() ?? ""

            // Build response dictionary to match Android/JS
            let response: [String: Any] = [
                "attestationObject": attestationObject,
                "clientDataJSON": clientDataJSON
            ]
            let result: [String: Any] = [
                "id": id,
                "rawId": rawId,
                "type": type,
                "response": response
            ]
            completeOnce(with: .success(result))

        case let credential as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            let id = credential.credentialID.toBase64URLEncoded()
            let rawId = credential.credentialID.toBase64URLEncoded()
            let type = "public-key"
            let clientDataJSON = credential.rawClientDataJSON.toBase64URLEncoded()
            let authenticatorData = credential.rawAuthenticatorData.toBase64URLEncoded()
            let signature = credential.signature.toBase64URLEncoded()
            let userHandle = credential.userID?.toBase64URLEncoded()

            var response: [String: Any] = [
                "clientDataJSON": clientDataJSON,
                "authenticatorData": authenticatorData,
                "signature": signature
            ]
            if let userHandle = userHandle {
                response["userHandle"] = userHandle
            }

            let result: [String: Any] = [
                "id": id,
                "rawId": rawId,
                "type": type,
                "response": response
            ]
            completeOnce(with: .success(result))

        case let credential as ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
            let id = credential.credentialID.toBase64URLEncoded()
            let rawId = credential.credentialID.toBase64URLEncoded()
            let type = "public-key"
            let clientDataJSON = credential.rawClientDataJSON.toBase64URLEncoded()
            let attestationObject = credential.rawAttestationObject?.toBase64URLEncoded() ?? ""

            // Build response dictionary to match platform credentials
            let response: [String: Any] = [
                "attestationObject": attestationObject,
                "clientDataJSON": clientDataJSON
            ]
            let result: [String: Any] = [
                "id": id,
                "rawId": rawId,
                "type": type,
                "response": response
            ]
            completeOnce(with: .success(result))

        case let credential as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            let id = credential.credentialID.toBase64URLEncoded()
            let rawId = credential.credentialID.toBase64URLEncoded()
            let type = "public-key"
            let clientDataJSON = credential.rawClientDataJSON.toBase64URLEncoded()
            let authenticatorData = credential.rawAuthenticatorData.toBase64URLEncoded()
            let signature = credential.signature.toBase64URLEncoded()
            let userHandle = credential.userID?.toBase64URLEncoded()

            var response: [String: Any] = [
                "clientDataJSON": clientDataJSON,
                "authenticatorData": authenticatorData,
                "signature": signature
            ]
            if let userHandle = userHandle {
                response["userHandle"] = userHandle
            }

            let result: [String: Any] = [
                "id": id,
                "rawId": rawId,
                "type": type,
                "response": response
            ]
            completeOnce(with: .success(result))

        default:
            let error = NSError(
                domain: "PasskeyDelegate",
                code: -300,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported credential type: \(type(of: authorization.credential))"]
            )
            completeOnce(with: .failure(error))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        #if DEBUG
        print("[PasskeyPlugin] Passkey flow failed: \(error.localizedDescription)")
        #endif
        completeOnce(with: .failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func performAuthForController(controller: ASAuthorizationController, timeout: TimeInterval? = nil, completion: @escaping (ResultData) -> Void) {
        self.completion = completion
        controller.delegate = self
        controller.presentationContextProvider = self
        
        // Set up timeout if provided
        if let timeoutInterval = timeout, timeoutInterval > 0 {
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval / 1000.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.handleTimeout()
                }
            }
        }
        
        controller.performRequests()
    }
    
    private func handleTimeout() {
        let timeoutError = NSError(
            domain: "PasskeyTimeout",
            code: -1004,
            userInfo: [NSLocalizedDescriptionKey: "Passkey operation timed out"]
        )
        completeOnce(with: .failure(timeoutError))
    }
    
    private func cleanupTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
