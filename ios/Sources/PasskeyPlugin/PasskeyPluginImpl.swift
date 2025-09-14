import Foundation
import AuthenticationServices


@available(iOS 15.0, *)
@objc public class PasskeyPluginImpl: NSObject {

    @objc public func createPasskey(_ publicKey: Data) async throws -> [String: Any] {
        let publicKeyStr = String(data: publicKey, encoding: .utf8) ?? "{}"
        print("Create passkey with JSON: " +  publicKeyStr)
        do {

            let requestData = publicKeyStr.data(using: .utf8)!;
            let requestJSON = try JSONDecoder().decode(PasskeyRegistrationOptions.self, from: requestData);

            guard let challengeData: Data = Data(base64URLEncoded: requestJSON.challenge) else {
                throw NSError(domain: "Passkey", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge or userId"])
            }

            guard let userIdData: Data = Data(base64URLEncoded: requestJSON.user.id) else {
                throw NSError(domain: "Passkey", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge or userId"])
            }

            let platformKeyRequest: ASAuthorizationRequest = self.configureCreatePlatformRequest(challenge: challengeData, userId: userIdData, request: requestJSON);
            let securityKeyRequest: ASAuthorizationRequest = self.configureCreateSecurityKeyRequest(challenge: challengeData, userId: userIdData, request: requestJSON);
            //TODO setup forceSecurityKey from request
            let forceSecurityKey:Bool = false;
            //TODO setup forcePlatformKey from request
            let forcePlatformKey:Bool = true;
            let authController: ASAuthorizationController = self.configureAuthController(forcePlatformKey: forcePlatformKey, forceSecurityKey: forceSecurityKey, platformKeyRequest: platformKeyRequest, securityKeyRequest: securityKeyRequest);

            let passkeyCredentialDelegate = await PasskeyCredentialDelegate()

            return try await withCheckedThrowingContinuation { continuation in
                passkeyCredentialDelegate.performAuthForController(controller: authController) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

        }catch let error as NSError {
            print("createPasskey failed: \(error.localizedDescription)")
            throw error
        }
    }


    @objc public func authenticate(_ publicKey: Data) async throws -> [String: Any] {
        let publicKeyStr = String(data: publicKey, encoding: .utf8) ?? "{}"
        do {
            let requestData = publicKeyStr.data(using: .utf8)!;
            let requestJSON = try JSONDecoder().decode(PasskeyAuthenticationOptions.self, from: requestData);

            guard let challengeData: Data = Data(base64URLEncoded: requestJSON.challenge) else {
                throw NSError(domain: "Passkey", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid challenge or userId"])
            }

            //TODO setup forceSecurityKey from request
            let forceSecurityKey:Bool = false;
            //TODO setup forcePlatformKey from request
            let forcePlatformKey:Bool = true;

            let platformKeyRequest: ASAuthorizationRequest = self.configureGetPlatformRequest(challenge: challengeData, request: requestJSON);
            let securityKeyRequest: ASAuthorizationRequest = self.configureGetSecurityKeyRequest(challenge: challengeData, request: requestJSON);

            // Get authorization controller
            let authController: ASAuthorizationController = self.configureAuthController(forcePlatformKey: forcePlatformKey, forceSecurityKey: forceSecurityKey, platformKeyRequest: platformKeyRequest, securityKeyRequest: securityKeyRequest);

            let passkeyCredentialDelegate = await PasskeyCredentialDelegate();

            return try await withCheckedThrowingContinuation { continuation in
                passkeyCredentialDelegate.performAuthForController(controller: authController) { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }catch let error as NSError {
            print("Create passkey failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func configureCreatePlatformRequest(challenge: Data, userId: Data, request: PasskeyRegistrationOptions) -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {

        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rp.id!);
        let authRequest = platformProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                               name: request.user.name,
                                                                               userID: userId);

        if #available(iOS 17.0, *) {
            if let largeBlob = request.extensions?.largeBlob {
                authRequest.largeBlob = largeBlob.support?.toApple()
            }
        }

        if #available(iOS 17.4, *) {
            if let excludeCredentials = request.excludeCredentials {
                authRequest.excludedCredentials = excludeCredentials.map({ $0.asPlatformDescriptor() })
            }
        }

        if let userVerificationPref = request.authenticatorSelection?.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.toApple()
        }
        return authRequest;
    }

    private func configureCreateSecurityKeyRequest(challenge: Data, userId: Data, request: PasskeyRegistrationOptions) -> ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest {

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: request.rp.id!);

        let authRequest = securityKeyProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                                  displayName: request.user.displayName,
                                                                                  name: request.user.name,
                                                                                  userID: userId);

        authRequest.credentialParameters = request.pubKeyCredParams.map({ $0.toAppleParams() })
        if #available(iOS 17.4, *) {
            if let excludeCredentials = request.excludeCredentials {
                authRequest.excludedCredentials = excludeCredentials.map({ $0.asCrossPlatformDescriptor() })
            }
        }

        if let residentCredPref = request.authenticatorSelection?.residentKey {
            authRequest.residentKeyPreference = residentCredPref.toApple()
        }

        if let userVerificationPref = request.authenticatorSelection?.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.toApple()
        }

        if let rpAttestationPref = request.attestation {
            authRequest.attestationPreference = rpAttestationPref.toApple()
        }

        return authRequest;
    }

    private func configureGetPlatformRequest(challenge: Data, request: PasskeyAuthenticationOptions) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {

        let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId);
        let authRequest = platformProvider.createCredentialAssertionRequest(challenge: challenge);

        if #available(iOS 17.0, *) {
            if request.extensions?.largeBlob?.read == true {
                authRequest.largeBlob = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.read;
            }

            if let largeBlobWriteData = request.extensions?.largeBlob?.write {
                authRequest.largeBlob = ASAuthorizationPublicKeyCredentialLargeBlobAssertionInput.write(largeBlobWriteData)
            }
        }

        if let allowCredentials = request.allowCredentials {
            authRequest.allowedCredentials = allowCredentials.map({ $0.asPlatformDescriptor() })
        }

        if let userVerificationPref = request.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.toApple()
        }

        return authRequest;
    }

    private func configureGetSecurityKeyRequest(challenge: Data, request: PasskeyAuthenticationOptions) -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {

        let securityKeyProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: request.rpId);

        let authRequest = securityKeyProvider.createCredentialAssertionRequest(challenge: challenge);

        if let allowCredentials = request.allowCredentials {
            authRequest.allowedCredentials = allowCredentials.map({ $0.asCrossPlatformDescriptor() })
        }

        if let userVerificationPref = request.userVerification {
            authRequest.userVerificationPreference = userVerificationPref.toApple()
        }

        return authRequest;
    }

    private func configureAuthController(forcePlatformKey: Bool, forceSecurityKey: Bool, platformKeyRequest: ASAuthorizationRequest, securityKeyRequest: ASAuthorizationRequest) -> ASAuthorizationController {
        if (forcePlatformKey) {
            return ASAuthorizationController(authorizationRequests: [platformKeyRequest]);
        }

        if (forceSecurityKey) {
            return ASAuthorizationController(authorizationRequests: [securityKeyRequest]);
        }

        return ASAuthorizationController(authorizationRequests: [platformKeyRequest, securityKeyRequest]);
    }
}
