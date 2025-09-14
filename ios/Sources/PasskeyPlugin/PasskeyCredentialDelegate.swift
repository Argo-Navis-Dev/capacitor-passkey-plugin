import Foundation
import AuthenticationServices
import UIKit

@available(iOS 15.0, *)
class PasskeyCredentialDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    typealias ResultData = Result<[String: Any], Error>
    var completion: ((ResultData) -> Void)?

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
            completion?(.success(result))

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
            completion?(.success(result))

        default:
            let error = NSError(
                domain: "PasskeyDelegate",
                code: Int(PasskeyPluginErrorCode.unsupportedCredentialType.rawValue) ?? -300,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported credential type: \(type(of: authorization.credential))"]
            )

            completion?(.failure(error))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Passkey flow failed: \(error.localizedDescription)")
        completion?(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func performAuthForController(controller: ASAuthorizationController, completion: @escaping (ResultData) -> Void) {
        self.completion = completion
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}
