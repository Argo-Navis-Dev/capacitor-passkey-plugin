import Foundation
import AuthenticationServices


@available(iOS 15.0, *)
@objc public class PasskeyPluginImpl: NSObject {
    
    private var passkeyDelegate: PasskeyDelegate?
    
    @objc public func createPasskey(_ publicKey: Data) -> String {
        print();
        
        let publicKeyStr = String(data: publicKey, encoding: .utf8) ?? "{}"
        
        do {
            var challenge: String?
            var userId: String?
            var rpId: String?
            
            if let jsonObject = try JSONSerialization.jsonObject(with: publicKey, options: []) as? [String: Any],
                let rp = jsonObject["rp"] as? [String: Any],
                let user = jsonObject["user"] as? [String: Any] {
                
                challenge = jsonObject["challenge"] as? String
                userId = user["id"] as? String
                rpId = rp["id"] as? String
                                                
            } else {
                print("Missing or invalid challenge/user.id")
            }
            
            guard let challenge = challenge, !challenge.isEmpty else {
                print("Challenge is nil or empty!")
                return "{}"
            }

            guard let userId = userId, !userId.isEmpty else {
                print("User ID is nil or empty!")
                return "{}"
            }
            
            guard let rpId = rpId, !rpId.isEmpty else {
                print("RPID is nil or empty!")
                return "{}"
            }
            
            print("Challenge: " + challenge)
            print("UserId: " + userId)
            print("RPID: " + rpId)
            
            
            let challengeData = Data(base64URLEncoded: challenge)
            guard let challengeData = challengeData, !challengeData.isEmpty else {
                print("Failed to convert challenge!")
                return "{}"
            }
            
            let userIdData = Data(base64URLEncoded: userId)
            guard let userIdData = userIdData, !userIdData.isEmpty else {
                print("Failed to convert userid!")
                return "{}"
            }
            
            
            let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
            let platformReq = platformProvider.createCredentialRegistrationRequest(challenge: challengeData,
                                                                                   name: "bence.nagy@aro-navis.dev",
                                                                                   userID: userIdData);
            
            let delegate = PasskeyDelegate()
            self.passkeyDelegate = delegate
            //self.passkeyDelegate = delegate
            // Get authorization controller
            let authController: ASAuthorizationController = ASAuthorizationController(authorizationRequests: [platformReq]);
            authController.delegate = delegate
            authController.presentationContextProvider = delegate
            authController.performRequests();
                
                
                /*if #available(iOS 17.0, *) {
                  if let largeBlob = request.extensions?.largeBlob {
                    authRequest.largeBlob = largeBlob.support?.appleise()
                  }
                }*/
                
                /*if #available(iOS 17.4, *) {
                  if let excludeCredentials = request.excludeCredentials {
                    authRequest.excludedCredentials = excludeCredentials.map({ $0.getPlatformDescriptor() })
                  }
                }
                
                if let userVerificationPref = request.authenticatorSelection?.userVerification {
                  authRequest.userVerificationPreference = userVerificationPref.appleise()
                }*/

       
            /*let authRequest = platformProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                                   name: request.user.name,
                                                                                   userID: userId);
            
            if #available(iOS 17.0, *) {
                if let largeBlob = request.extensions?.largeBlob {
                    authRequest.largeBlob = largeBlob.support?.appleise()
                }
            }
            
            if #available(iOS 17.4, *) {
                if let excludeCredentials = request.excludeCredentials {
                    authRequest.excludedCredentials = excludeCredentials.map({ $0.getPlatformDescriptor() })
                }
            }
            if let userVerificationPref = request.authenticatorSelection?.userVerification {
                authRequest.userVerificationPreference = userVerificationPref.appleise()
            }
            
            return authRequest;*/
        }catch let error as NSError {
            print(error)
        }
        
        return "{}"
    }
    
   /* private func configureCreatePlatformRequest(challenge: Data, userId: Data, request: RNPasskeyCredentialCreationOptions) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        
        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rp.id!);
        
        let authRequest = platformProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                               name: request.user.name,
                                                                               userID: userId);
        
        if #available(iOS 17.0, *) {
          if let largeBlob = request.extensions?.largeBlob {
            authRequest.largeBlob = largeBlob.support?.appleise()
          }
        }
        
        if #available(iOS 17.4, *) {
          if let excludeCredentials = request.excludeCredentials {
            authRequest.excludedCredentials = excludeCredentials.map({ $0.getPlatformDescriptor() })
          }
        }
        
        if let userVerificationPref = request.authenticatorSelection?.userVerification {
          authRequest.userVerificationPreference = userVerificationPref.appleise()
        }

        return authRequest;
        
    }*/
    
    @objc public func authenticate(_ value: String) -> String {
        print("Hello1234")
        print(value)
        return value
    }
}
