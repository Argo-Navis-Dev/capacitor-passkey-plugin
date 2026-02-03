# iOS Platform Guide

This guide covers iOS-specific configuration, requirements, and implementation details for the Capacitor Passkey Plugin.

## Requirements

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| iOS         | 15.0            | Passkey APIs require iOS 15+ |
| Xcode       | 14.0+           | Required for building |
| Swift       | 5.1+            | Used by the plugin |

## Feature Availability by iOS Version

| iOS Version | Feature Support |
|-------------|-----------------|
| 15.0+       | Platform passkeys (Face ID / Touch ID), YubiKey / security key support |
| 16.0+       | Cross-device authentication, security key improvements |
| 17.0+       | Enhanced passkey syncing, conditional UI |

## Configuration

### Associated Domains

To enable passkey operations, configure Associated Domains in your Capacitor app's Xcode project:

1. Open your Capacitor app project in Xcode (typically at `ios/App/App.xcworkspace`)
2. Select your app target
3. Go to "Signing & Capabilities"
4. Add "Associated Domains" capability
5. Add `webcredentials:yourdomain.com` (replace with your actual domain)

Your server must also host an `apple-app-site-association` file at `https://yourdomain.com/.well-known/apple-app-site-association`:

```json
{
  "webcredentials": {
    "apps": ["TEAM_ID.com.yourcompany.yourapp"]
  }
}
```

Replace `TEAM_ID` with your Apple Team ID and `com.yourcompany.yourapp` with your app's bundle identifier.

## Authenticator Selection

The iOS implementation supports different authenticator types based on the `authenticatorAttachment` setting:

| Value | Behavior |
|-------|----------|
| `"platform"` | Forces built-in authenticators (Touch ID, Face ID) |
| `"cross-platform"` | Forces external security keys (YubiKey, etc.) |
| Not specified | Allows both types (recommended for flexibility) |

### Platform Authenticators

Platform authenticators use the device's built-in biometric authentication:
- Face ID on supported iPhones and iPads
- Touch ID on supported devices
- Device passcode as fallback

### Security Keys (YubiKey)

The plugin supports external FIDO2 security keys like YubiKey:

```typescript
const credential = await PasskeyPlugin.createPasskey({
  publicKey: {
    // ... other options
    authenticatorSelection: {
      authenticatorAttachment: 'cross-platform',
      userVerification: 'required'
    }
  }
});
```

Supported transports for security keys:
- `usb` - USB-A or USB-C connected keys
- `nfc` - NFC-enabled keys (iPhone 7 and later)

## Implementation Details

### Native Framework

The plugin uses Apple's Authentication Services framework (`ASAuthorization`):
- `ASAuthorizationPlatformPublicKeyCredentialProvider` for platform passkeys
- `ASAuthorizationSecurityKeyPublicKeyCredentialProvider` for external security keys

### rpId Validation

iOS validates the `rpId` against the app's associated domains. If validation fails, you'll receive an `RPID_VALIDATION_ERROR`. Ensure:
- The `rpId` matches a domain in your `com.apple.developer.web-credentials` entitlement
- Your server hosts a valid `apple-app-site-association` file
- The domain is accessible over HTTPS

### Timeout Handling

The plugin enforces the timeout specified in your options. If the user doesn't complete authentication within the timeout period, a `TIMEOUT` error is returned.

## Error Codes

iOS-specific error mappings:

| Error Code | iOS Error | Description |
|------------|-----------|-------------|
| `CANCELLED` | `ASAuthorizationError.canceled` | User cancelled the operation |
| `DOM_ERROR` | `ASAuthorizationError.invalidResponse` | Invalid response from authenticator |
| `NO_CREDENTIAL` | `ASAuthorizationError.notHandled` | No matching credential found |
| `UNSUPPORTED_ERROR` | `ASAuthorizationError.notInteractive` | Operation not supported |
| `INVALID_INPUT` | `ASAuthorizationError.matchedExcludedCredential` | Credential already exists |
| `RPID_VALIDATION_ERROR` | Validation failure | rpId not in associated domains |
| `TIMEOUT` | Timeout exceeded | Operation timed out |

## Troubleshooting

### Passkey creation fails with RPID_VALIDATION_ERROR

1. Verify your Associated Domains capability includes the correct domain (in Xcode: Signing & Capabilities)
2. Check that `apple-app-site-association` is accessible at `https://yourdomain.com/.well-known/apple-app-site-association`
3. Ensure the Team ID in the association file matches your app's Team ID
4. Clear the association cache: Settings > Developer > Associated Domains Development

### YubiKey not detected

1. Ensure the key supports FIDO2/WebAuthn
2. For NFC keys, hold the key near the top of the iPhone
3. For USB keys, ensure the device supports USB accessories
4. Set `authenticatorAttachment: 'cross-platform'` in your options

### Face ID / Touch ID not prompting

1. Ensure biometric authentication is enabled in device settings
2. Check that your app has the required usage descriptions in `Info.plist`
3. Verify the device supports the requested authentication method
