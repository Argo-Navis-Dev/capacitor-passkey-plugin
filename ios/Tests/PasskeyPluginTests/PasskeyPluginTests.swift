import XCTest
import AuthenticationServices
@testable import PasskeyPlugin

@available(iOS 15.0, *)
class PasskeyPluginTests: XCTestCase {

    // MARK: - Base64URL Encoding/Decoding Tests

    func testBase64URLDecoding_validInput() {
        // Standard base64url string (no padding)
        let base64url = "SGVsbG8gV29ybGQ"  // "Hello World"
        let data = Data(base64URLEncoded: base64url)

        XCTAssertNotNil(data)
        XCTAssertEqual(String(data: data!, encoding: .utf8), "Hello World")
    }

    func testBase64URLDecoding_withSpecialCharacters() {
        // Base64url uses - and _ instead of + and /
        let base64url = "PDw_Pz4-"  // "<<??>>", contains + and / in standard base64
        let data = Data(base64URLEncoded: base64url)

        XCTAssertNotNil(data)
    }

    func testBase64URLDecoding_emptyString() {
        let data = Data(base64URLEncoded: "")
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 0)
    }

    func testBase64URLDecoding_invalidInput() {
        // Invalid base64 characters
        let data = Data(base64URLEncoded: "!!!invalid!!!")
        XCTAssertNil(data)
    }

    func testBase64URLEncoding_roundTrip() {
        let originalString = "Test data for passkey"
        let originalData = originalString.data(using: .utf8)!

        let encoded = originalData.toBase64URLEncoded()
        let decoded = Data(base64URLEncoded: encoded)

        XCTAssertNotNil(decoded)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), originalString)
    }

    func testBase64URLEncoding_noPadding() {
        let data = "Hi".data(using: .utf8)!
        let encoded = data.toBase64URLEncoded()

        // Should not contain padding characters
        XCTAssertFalse(encoded.contains("="))
    }

    func testBase64URLEncoding_noStandardBase64Chars() {
        // Create data that would produce + and / in standard base64
        let data = Data([0x3e, 0x3f, 0xfb, 0xef])  // Will produce +/characters in standard base64
        let encoded = data.toBase64URLEncoded()

        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
    }

    // MARK: - PasskeyCredentialParameters Decoding Tests

    func testCredentialParameters_validInput() throws {
        let json = """
        {"alg": -7, "type": "public-key"}
        """
        let data = json.data(using: .utf8)!

        let params = try JSONDecoder().decode(PasskeyCredentialParameters.self, from: data)

        XCTAssertEqual(params.alg, ASCOSEAlgorithmIdentifier.ES256)
        XCTAssertEqual(params.type, .publicKey)
    }

    func testCredentialParameters_RS256Algorithm() throws {
        let json = """
        {"alg": -257, "type": "public-key"}
        """
        let data = json.data(using: .utf8)!

        let params = try JSONDecoder().decode(PasskeyCredentialParameters.self, from: data)

        XCTAssertEqual(params.alg.rawValue, -257)
    }

    func testCredentialParameters_missingAlg() {
        let json = """
        {"type": "public-key"}
        """
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PasskeyCredentialParameters.self, from: data)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                XCTFail("Expected keyNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(key.stringValue, "alg")
        }
    }

    func testCredentialParameters_missingType() {
        let json = """
        {"alg": -7}
        """
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PasskeyCredentialParameters.self, from: data)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                XCTFail("Expected keyNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(key.stringValue, "type")
        }
    }

    func testCredentialParameters_invalidType() {
        let json = """
        {"alg": -7, "type": "invalid-type"}
        """
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PasskeyCredentialParameters.self, from: data)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Expected dataCorrupted error, got \(error)")
                return
            }
            XCTAssertTrue(context.debugDescription.contains("Invalid credential type"))
        }
    }

    // MARK: - PasskeyCredentialDescriptor Decoding Tests

    func testCredentialDescriptor_validInput() throws {
        let json = """
        {"id": "dGVzdC1jcmVkZW50aWFsLWlk", "type": "public-key"}
        """
        let data = json.data(using: .utf8)!

        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        XCTAssertEqual(descriptor.id, "dGVzdC1jcmVkZW50aWFsLWlk")
        XCTAssertEqual(descriptor.type, .publicKey)
        XCTAssertNil(descriptor.transports)
    }

    func testCredentialDescriptor_withTransports() throws {
        let json = """
        {"id": "dGVzdC1pZA", "type": "public-key", "transports": ["usb", "nfc", "ble"]}
        """
        let data = json.data(using: .utf8)!

        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        XCTAssertNotNil(descriptor.transports)
        XCTAssertEqual(descriptor.transports?.count, 3)
        XCTAssertTrue(descriptor.transports!.contains(.usb))
        XCTAssertTrue(descriptor.transports!.contains(.nfc))
        XCTAssertTrue(descriptor.transports!.contains(.ble))
    }

    func testCredentialDescriptor_missingId() {
        let json = """
        {"type": "public-key"}
        """
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                XCTFail("Expected keyNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(key.stringValue, "id")
        }
    }

    func testCredentialDescriptor_defaultTypeIsPublicKey() throws {
        let json = """
        {"id": "dGVzdC1pZA"}
        """
        let data = json.data(using: .utf8)!

        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        XCTAssertEqual(descriptor.type, .publicKey)
    }

    // MARK: - Transport Conversion Tests

    func testTransport_usbConversion() {
        let transport = PasskeyAuthTransport.usb
        let appleTransport = transport.toAppleTransport()

        XCTAssertNotNil(appleTransport)
        XCTAssertEqual(appleTransport, .usb)
    }

    func testTransport_nfcConversion() {
        let transport = PasskeyAuthTransport.nfc
        let appleTransport = transport.toAppleTransport()

        XCTAssertNotNil(appleTransport)
        XCTAssertEqual(appleTransport, .nfc)
    }

    func testTransport_bleConversion() {
        let transport = PasskeyAuthTransport.ble
        let appleTransport = transport.toAppleTransport()

        XCTAssertNotNil(appleTransport)
        XCTAssertEqual(appleTransport, .bluetooth)
    }

    func testTransport_hybridNotSupported() {
        let transport = PasskeyAuthTransport.hybrid
        let appleTransport = transport.toAppleTransport()

        XCTAssertNil(appleTransport)
    }

    // MARK: - PasskeyUserVerificationReq Tests

    func testUserVerification_discouragedConversion() {
        let pref = PasskeyUserVerificationReq.discouraged
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .discouraged)
    }

    func testUserVerification_preferredConversion() {
        let pref = PasskeyUserVerificationReq.preferred
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .preferred)
    }

    func testUserVerification_requiredConversion() {
        let pref = PasskeyUserVerificationReq.required
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .required)
    }

    // MARK: - PasskeyResidentKeyReq Tests

    func testResidentKey_discouragedConversion() {
        let pref = PasskeyResidentKeyReq.discouraged
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .discouraged)
    }

    func testResidentKey_preferredConversion() {
        let pref = PasskeyResidentKeyReq.preferred
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .preferred)
    }

    func testResidentKey_requiredConversion() {
        let pref = PasskeyResidentKeyReq.required
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .required)
    }

    // MARK: - PasskeyAttestationConveyancePref Tests

    func testAttestation_directConversion() {
        let pref = PasskeyAttestationConveyancePref.direct
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .direct)
    }

    func testAttestation_indirectConversion() {
        let pref = PasskeyAttestationConveyancePref.indirect
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .indirect)
    }

    func testAttestation_noneConversion() {
        let pref = PasskeyAttestationConveyancePref.none
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .none)
    }

    func testAttestation_enterpriseConversion() {
        let pref = PasskeyAttestationConveyancePref.enterprise
        let applePref = pref.toApple()

        XCTAssertEqual(applePref, .enterprise)
    }

    // MARK: - PasskeyAuthAttachment Tests

    func testAuthAttachment_platformDecoding() throws {
        let json = """
        {"authenticatorAttachment": "platform"}
        """
        let data = json.data(using: .utf8)!

        let criteria = try JSONDecoder().decode(PasskeyAuthSelectionCriteria.self, from: data)

        XCTAssertEqual(criteria.authenticatorAttachment, .platform)
    }

    func testAuthAttachment_crossPlatformDecoding() throws {
        let json = """
        {"authenticatorAttachment": "cross-platform"}
        """
        let data = json.data(using: .utf8)!

        let criteria = try JSONDecoder().decode(PasskeyAuthSelectionCriteria.self, from: data)

        XCTAssertEqual(criteria.authenticatorAttachment, .crossPlatform)
    }

    // MARK: - PasskeyRegistrationOptions Decoding Tests

    func testRegistrationOptions_validMinimalInput() throws {
        let json = """
        {
            "rp": {"name": "Test RP", "id": "example.com"},
            "user": {"id": "dXNlci1pZA", "name": "user@example.com", "displayName": "Test User"},
            "challenge": "Y2hhbGxlbmdl",
            "pubKeyCredParams": [{"alg": -7, "type": "public-key"}]
        }
        """
        let data = json.data(using: .utf8)!

        let options = try JSONDecoder().decode(PasskeyRegistrationOptions.self, from: data)

        XCTAssertEqual(options.rp.name, "Test RP")
        XCTAssertEqual(options.rp.id, "example.com")
        XCTAssertEqual(options.user.name, "user@example.com")
        XCTAssertEqual(options.challenge, "Y2hhbGxlbmdl")
        XCTAssertEqual(options.pubKeyCredParams.count, 1)
    }

    func testRegistrationOptions_withOptionalFields() throws {
        let json = """
        {
            "rp": {"name": "Test RP", "id": "example.com"},
            "user": {"id": "dXNlci1pZA", "name": "user@example.com", "displayName": "Test User"},
            "challenge": "Y2hhbGxlbmdl",
            "pubKeyCredParams": [{"alg": -7, "type": "public-key"}],
            "timeout": 60000,
            "attestation": "direct",
            "authenticatorSelection": {
                "authenticatorAttachment": "platform",
                "userVerification": "required",
                "residentKey": "required"
            }
        }
        """
        let data = json.data(using: .utf8)!

        let options = try JSONDecoder().decode(PasskeyRegistrationOptions.self, from: data)

        XCTAssertEqual(options.timeout, 60000)
        XCTAssertEqual(options.attestation, .direct)
        XCTAssertEqual(options.authenticatorSelection?.authenticatorAttachment, .platform)
        XCTAssertEqual(options.authenticatorSelection?.userVerification, .required)
        XCTAssertEqual(options.authenticatorSelection?.residentKey, .required)
    }

    // MARK: - PasskeyAuthenticationOptions Decoding Tests

    func testAuthenticationOptions_validMinimalInput() throws {
        let json = """
        {
            "challenge": "Y2hhbGxlbmdl",
            "rpId": "example.com"
        }
        """
        let data = json.data(using: .utf8)!

        let options = try JSONDecoder().decode(PasskeyAuthenticationOptions.self, from: data)

        XCTAssertEqual(options.challenge, "Y2hhbGxlbmdl")
        XCTAssertEqual(options.rpId, "example.com")
    }

    func testAuthenticationOptions_withAllowCredentials() throws {
        let json = """
        {
            "challenge": "Y2hhbGxlbmdl",
            "rpId": "example.com",
            "allowCredentials": [
                {"id": "Y3JlZC0x", "type": "public-key", "transports": ["usb"]},
                {"id": "Y3JlZC0y", "type": "public-key"}
            ],
            "userVerification": "preferred",
            "timeout": 30000
        }
        """
        let data = json.data(using: .utf8)!

        let options = try JSONDecoder().decode(PasskeyAuthenticationOptions.self, from: data)

        XCTAssertEqual(options.allowCredentials?.count, 2)
        XCTAssertEqual(options.userVerification, .preferred)
        XCTAssertEqual(options.timeout, 30000)
    }

    // MARK: - Credential Descriptor Conversion Tests

    func testCredentialDescriptor_asPlatformDescriptor_validId() throws {
        let json = """
        {"id": "dGVzdC1pZA", "type": "public-key"}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let platformDescriptor = descriptor.asPlatformDescriptor()

        XCTAssertNotNil(platformDescriptor)
    }

    func testCredentialDescriptor_asPlatformDescriptor_invalidId() throws {
        let json = """
        {"id": "!!!invalid-base64!!!", "type": "public-key"}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let platformDescriptor = descriptor.asPlatformDescriptor()

        XCTAssertNil(platformDescriptor)
    }

    func testCredentialDescriptor_asCrossPlatformDescriptor_validId() throws {
        let json = """
        {"id": "dGVzdC1pZA", "type": "public-key", "transports": ["usb", "nfc"]}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let crossPlatformDescriptor = descriptor.asCrossPlatformDescriptor()

        XCTAssertNotNil(crossPlatformDescriptor)
    }

    func testCredentialDescriptor_asCrossPlatformDescriptor_invalidId() throws {
        let json = """
        {"id": "!!!invalid!!!", "type": "public-key"}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let crossPlatformDescriptor = descriptor.asCrossPlatformDescriptor()

        XCTAssertNil(crossPlatformDescriptor)
    }

    func testCredentialDescriptor_asCrossPlatformDescriptor_unsupportedTransportsFiltered() throws {
        // hybrid is not supported on iOS
        let json = """
        {"id": "dGVzdC1pZA", "type": "public-key", "transports": ["hybrid", "usb"]}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let crossPlatformDescriptor = descriptor.asCrossPlatformDescriptor()

        // Should still create descriptor with supported transports
        XCTAssertNotNil(crossPlatformDescriptor)
    }

    func testCredentialDescriptor_asCrossPlatformDescriptor_allUnsupportedFallsBackToAll() throws {
        // Only hybrid which is not supported
        let json = """
        {"id": "dGVzdC1pZA", "type": "public-key", "transports": ["hybrid"]}
        """
        let data = json.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PasskeyCredentialDescriptor.self, from: data)

        let crossPlatformDescriptor = descriptor.asCrossPlatformDescriptor()

        // Should fall back to all supported transports
        XCTAssertNotNil(crossPlatformDescriptor)
    }

    // MARK: - Error Code Tests

    func testErrorCode_rawValues() {
        XCTAssertEqual(PasskeyPluginErrorCode.unknown.rawValue, "UNKNOWN_ERROR")
        XCTAssertEqual(PasskeyPluginErrorCode.cancelled.rawValue, "CANCELLED")
        XCTAssertEqual(PasskeyPluginErrorCode.domError.rawValue, "DOM_ERROR")
        XCTAssertEqual(PasskeyPluginErrorCode.unsupported.rawValue, "UNSUPPORTED_ERROR")
        XCTAssertEqual(PasskeyPluginErrorCode.timeout.rawValue, "TIMEOUT")
        XCTAssertEqual(PasskeyPluginErrorCode.noCredential.rawValue, "NO_CREDENTIAL")
        XCTAssertEqual(PasskeyPluginErrorCode.invalidInput.rawValue, "INVALID_INPUT")
        XCTAssertEqual(PasskeyPluginErrorCode.rpIdValidation.rawValue, "RPID_VALIDATION_ERROR")
    }
}
