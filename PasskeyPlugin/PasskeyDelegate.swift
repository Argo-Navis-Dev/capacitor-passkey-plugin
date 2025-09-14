import Foundation
import AuthenticationServices
import UIKit

@available(iOS 15.0, *)
class PasskeyDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let rawId = credential.credentialID
            let attestationObject = credential.rawAttestationObject
            let clientDataJSON = credential.rawClientDataJSON
            
            print("Passkey created!")
            print("Credential ID: \(rawId.base64EncodedString())")
            // Return these values to JS or handle as needed
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
           print("Failed to create passkey: \(error.localizedDescription)")
           // Handle the error (e.g., show alert or reject promise)
       }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
           return UIApplication.shared.windows.first { $0.isKeyWindow }!
       }
 
}
