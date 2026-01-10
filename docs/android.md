# Android Platform Guide

This guide covers Android-specific configuration, requirements, and implementation details for the Capacitor Passkey Plugin.

## Requirements

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Android     | 9.0 (API 28)    | Credential Manager API |
| Target SDK  | 35              | Recommended |
| Kotlin      | 2.1+            | Used by the plugin |

## Feature Availability by Android Version

| Android Version | Feature Support |
|-----------------|-----------------|
| 9.0+ (API 28)   | Basic passkey support via Credential Manager |
| 14+ (API 34)    | Enhanced Credential Manager, improved UX |

## Dependencies

The plugin uses the following Android libraries:

```gradle
implementation "androidx.credentials:credentials:1.5.0"
```

## Configuration

### Digital Asset Links

Configure your domain in `android/app/src/main/res/values/strings.xml`:

```xml
<string name="asset_statements" translatable="false">
[{
  "include": "https://yourdomain.com/.well-known/assetlinks.json"
}]
</string>
```

### Server Configuration

Host an `assetlinks.json` file at `https://yourdomain.com/.well-known/assetlinks.json`:

```json
[{
  "relation": ["delegate_permission/common.get_login_creds", "delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourcompany.yourapp",
    "sha256_cert_fingerprints": [
      "YOUR_APP_SIGNING_CERTIFICATE_SHA256_FINGERPRINT"
    ]
  }
}]
```

To get your app's SHA256 fingerprint:

```bash
# For debug builds
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For release builds
keytool -list -v -keystore your-release-key.keystore -alias your-alias
```

## Authenticator Selection

The Android implementation supports different authenticator types:

| Value | Behavior |
|-------|----------|
| `"platform"` | Uses device's built-in authenticators (fingerprint, face, PIN) |
| `"cross-platform"` | Uses external security keys |
| Not specified | Allows both types |

### Platform Authenticators

Android platform authenticators include:
- Fingerprint sensors
- Face unlock (on supported devices)
- Device PIN/pattern as fallback
- Google Password Manager for passkey storage and sync

### Security Keys

External FIDO2 security keys are supported via:
- USB connection
- NFC (on supported devices)
- Bluetooth (limited support)

## Implementation Details

### Credential Manager API

The plugin uses Android's Credential Manager API for passkey operations:
- Provides a unified interface for credential management
- Handles the complexity of different authenticator types
- Supports passkey syncing across devices via Google Password Manager

### Coroutines

The Android implementation uses Kotlin coroutines for async operations:
- Operations run on `Dispatchers.Main` for UI interactions
- Timeout is enforced using `withTimeout()`
- Coroutine scope is properly cancelled in `handleOnDestroy()`

### Input Validation

The plugin validates base64url-encoded inputs before processing:
- Challenges must be valid base64url format
- Credential IDs are validated before authentication
- Invalid input returns `INVALID_INPUT` error code

## Error Codes

Android-specific error mappings:

| Error Code | Android Exception | Description |
|------------|-------------------|-------------|
| `CANCELLED` | `GetCredentialCancellationException` | User cancelled the operation |
| `NO_CREDENTIAL` | `NoCredentialException` | No matching credential found |
| `UNSUPPORTED_ERROR` | `GetCredentialUnsupportedException` | Passkeys not supported |
| `INVALID_INPUT` | Validation failure | Invalid base64url input |
| `TIMEOUT` | `TimeoutCancellationException` | Operation timed out |
| `UNKNOWN_ERROR` | Other exceptions | Unexpected error |

## Troubleshooting

### "No credentials available" error

1. Verify Digital Asset Links are correctly configured
2. Check that `assetlinks.json` is accessible over HTTPS
3. Ensure the package name and SHA256 fingerprint match your app
4. Test asset links: `adb shell am start -a android.intent.action.VIEW -d "https://yourdomain.com/.well-known/assetlinks.json"`

### Credential Manager not available

1. Ensure the device runs Android 9.0 or later
2. Check that Google Play Services is up to date
3. Verify the device has a screen lock configured

### Passkeys not syncing

1. Ensure the user is signed into their Google account
2. Check that Google Password Manager is enabled
3. Verify sync is enabled in device settings

### Security key not detected

1. For USB keys, ensure USB debugging is disabled
2. For NFC keys, ensure NFC is enabled in device settings
3. Check that the security key supports FIDO2/WebAuthn
