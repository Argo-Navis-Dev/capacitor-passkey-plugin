# Android Platform Guide

This guide covers Android-specific configuration, requirements, and implementation details for the Capacitor Passkey Plugin.

## Requirements

| Requirement | Minimum Version | Notes |
|-------------|-----------------|-------|
| Android     | 9.0 (API 28)    | Credential Manager API required |
| Target SDK  | 35              | Recommended for latest features |
| Kotlin      | 2.1+            | Used by the plugin |
| Google Play Services | Latest | Required for passkey sync |

## Feature Availability by Android Version

| Android Version | Feature Support |
|-----------------|-----------------|
| 9.0+ (API 28)   | Basic passkey support via Credential Manager API |
| 14+ (API 34)    | Enhanced Credential Manager UI, improved security key (YubiKey) support |

## Dependencies

The plugin automatically includes the following Android libraries:

```gradle
implementation "androidx.credentials:credentials:1.5.0"
```

No additional configuration is needed as the plugin handles all dependencies and permissions (including NFC for YubiKey support).

## Configuration

### Digital Asset Links

**Step 1:** Add the asset statements resource in `android/app/src/main/res/values/strings.xml`:

```xml
<string name="asset_statements" translatable="false">
[{
  \"include\": \"https://yourdomain.com/.well-known/assetlinks.json\"
}]
</string>
```

**Step 2:** Add the meta-data tag in `android/app/src/main/AndroidManifest.xml` inside the `<activity>` tag:

```xml
<activity ...>
    <!-- Existing intent filters -->

    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" />
        <data android:host="yourdomain.com" />
    </intent-filter>

    <meta-data
        android:name="asset_statements"
        android:resource="@string/asset_statements" />
</activity>
```

**Step 3:** Host an `assetlinks.json` file at `https://yourdomain.com/.well-known/assetlinks.json`:

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

External FIDO2 security keys (YubiKey) are supported via:
- USB connection
- NFC (on supported devices)
- Bluetooth (limited support)

## Implementation Details

### Native Framework

The plugin uses Android's Credential Manager API (`androidx.credentials`) for passkey operations:
- `CreatePublicKeyCredentialRequest` for passkey creation
- `GetPublicKeyCredentialOption` for authentication
- Provides a unified interface across different authenticator types
- Supports passkey syncing across devices via Google Password Manager

### Single-File Architecture

All Android implementation is contained in [PasskeyPlugin.kt](../android/src/main/java/com/argonavisdev/capacitorpasskeyplugin/PasskeyPlugin.kt):
- `createPasskey()` - Handles passkey registration
- `authenticate()` - Handles passkey authentication
- `handleCreatePasskeyException()` - Maps creation exceptions to standard error codes
- `handleAuthenticationError()` - Maps authentication exceptions to standard error codes
- `isValidBase64Url()` - Validates base64url encoded inputs

### Coroutine Management

The plugin uses Kotlin coroutines for async operations:
- Operations run on `Dispatchers.IO` for network/credential operations
- Main scope created with `SupervisorJob()` for independent failure handling
- Timeout enforced using `withTimeout()` from publicKey options
- Coroutine scope properly cancelled in `handleOnDestroy()` to prevent memory leaks

### Input Validation

The plugin validates all inputs before processing:
- Challenges must be valid base64url format (checked with regex and decode test)
- User IDs validated for base64url encoding
- Authenticator attachment must be `"platform"`, `"cross-platform"`, or omitted
- Invalid input returns `INVALID_INPUT` error code with descriptive message

### Digital Asset Links Validation

Android validates the `rpId` against the app's Digital Asset Links configuration. For successful passkey operations:
- The `rpId` must match a domain configured in your `strings.xml` asset statements
- The server must host a valid `assetlinks.json` file at `https://rpId/.well-known/assetlinks.json`
- The package name and SHA256 fingerprint in `assetlinks.json` must match your app
- The domain must be accessible over HTTPS

Unlike iOS, Android doesn't return a specific validation error - it simply won't find or create credentials if validation fails.

### Timeout Handling

The plugin enforces the timeout specified in `publicKey.timeout`:
- Default timeout: 60 seconds (60000ms)
- Uses Kotlin's `withTimeout()` for precise timeout enforcement
- Returns `TIMEOUT` error code if the operation exceeds the limit
- Timeout applies to the entire operation including user interaction

### Security Key Support

For external security keys (YubiKey, etc.):
- Set `preferImmediatelyAvailableCredentials: false` for cross-platform authenticators
- Validates that `transports` hints are provided for better key detection
- Supports USB, NFC, and limited Bluetooth connectivity
- Logs warnings when transport hints are missing from credential descriptors

### Base64url Encoding

The plugin handles base64url encoding for WebAuthn data:
- Validates input format using regex pattern: `^[A-Za-z0-9_-]+$`
- Converts base64url to standard base64 for Android's `Base64.decode()`
- Adds padding if needed (base64url omits padding characters)
- Returns `INVALID_INPUT` error if validation or decoding fails

### Logging and Debugging

The plugin logs important events and errors for debugging:
- Creation/authentication attempts with rpId (sensitive data excluded)
- Authenticator attachment type being used
- Transport hint warnings for security keys
- Detailed error messages with exception types and error details
- DOM exceptions now include type, errorMessage, and message properties for comprehensive debugging
- Success confirmations (without credential data)

View logs using:
```bash
adb logcat PasskeyPlugin:D *:S
```

#### DOM Exception Logging

When a DOM exception occurs (common with YubiKey/security key operations), the plugin now logs:
- `type`: The credential exception type
- `errorMessage`: The structured error message from the Credential Manager
- `message`: The exception's base message

This enhanced logging helps diagnose issues like:
- Invalid rpId configuration
- Security key compatibility problems
- WebAuthn protocol errors
- Device/platform limitations

## Error Codes

Android-specific error mappings:

### Creation Errors

| Error Code | Android Exception | Description |
|------------|-------------------|-------------|
| `CANCELLED` | `CreateCredentialCancellationException` | User cancelled passkey creation |
| `DOM_ERROR` | `CreatePublicKeyCredentialDomException` | WebAuthn DOM exception during creation |
| `INTERRUPTED` | `CreateCredentialInterruptedException` | Creation process was interrupted |
| `PROVIDER_CONFIG_ERROR` | `CreateCredentialProviderConfigurationException` | Credential provider misconfigured |
| `UNSUPPORTED_ERROR` | `CreateCredentialUnsupportedException` | Passkey creation not supported on device |
| `INVALID_INPUT` | Validation failure | Invalid challenge, user ID, or authenticatorAttachment |
| `TIMEOUT` | `TimeoutCancellationException` | Creation timed out (from publicKey.timeout) |
| `UNKNOWN_ERROR` | `CreateCredentialUnknownException` or other | Unexpected error during creation |

### Authentication Errors

| Error Code | Android Exception | Description |
|------------|-------------------|-------------|
| `CANCELLED` | `GetCredentialCancellationException` | User cancelled authentication |
| `DOM_ERROR` | `GetPublicKeyCredentialDomException` | WebAuthn DOM exception during authentication |
| `INTERRUPTED` | `GetCredentialInterruptedException` | Authentication was interrupted |
| `PROVIDER_CONFIG_ERROR` | `GetCredentialProviderConfigurationException` | Credential provider misconfigured |
| `NO_CREDENTIAL` | `NoCredentialException` | No matching passkey found |
| `UNSUPPORTED_ERROR` | `GetCredentialUnsupportedException` | Passkey authentication not supported |
| `INVALID_INPUT` | Validation failure | Invalid challenge or authenticatorAttachment |
| `TIMEOUT` | `TimeoutCancellationException` | Authentication timed out |
| `UNKNOWN_ERROR` | `GetCredentialUnknownException` or other | Unexpected error during authentication |

### Special Cases

For `UNSUPPORTED_ERROR` with `authenticatorAttachment: "cross-platform"`, the error message includes guidance about NFC and FIDO2/WebAuthn support.

## Troubleshooting

### "No credentials available" error

**Symptom**: `NO_CREDENTIAL` error when trying to authenticate, or creation fails silently

**Solutions**:
1. Verify Digital Asset Links are correctly configured in `strings.xml`
2. Check that `assetlinks.json` is accessible at `https://yourdomain.com/.well-known/assetlinks.json`
3. Ensure the package name in `assetlinks.json` matches your app's package name exactly
4. Verify SHA256 fingerprint matches your app signing certificate:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256
   ```
5. Test asset links verification:
   ```bash
   adb shell pm get-app-links com.yourcompany.yourapp
   ```
6. Clear app data and retry

### Credential Manager not available

**Symptom**: `UNSUPPORTED_ERROR` when calling passkey methods

**Solutions**:
1. Ensure the device runs Android 9.0 (API 28) or later
2. Update Google Play Services to the latest version
3. Verify the device has a screen lock configured (PIN, pattern, fingerprint, or face unlock)
4. Check that the app has the required permissions
5. For emulators, ensure the system image includes Google Play Services

### Passkeys not syncing across devices

**Symptom**: Passkeys created on one device don't appear on another

**Solutions**:
1. Ensure the user is signed into the same Google account on both devices
2. Check that Google Password Manager is enabled (Settings > Passwords & accounts)
3. Verify sync is enabled (Settings > Accounts > Google > Account sync)
4. Allow time for sync to propagate (can take several minutes)
5. Check network connectivity on both devices

### YubiKey / Security key not detected

**Symptom**: `UNSUPPORTED_ERROR` or timeout when using `authenticatorAttachment: "cross-platform"`

**Solutions**:
1. For USB keys:
   - Disable USB debugging temporarily
   - Ensure the device supports USB OTG (On-The-Go)
   - Try a different USB adapter if using USB-C to USB-A
2. For NFC keys:
   - Enable NFC in device settings (Settings > Connected devices > Connection preferences > NFC)
   - Hold the key against the NFC antenna (usually near the top of the phone)
   - Keep the key steady for 2-3 seconds
3. Verify the security key supports FIDO2/WebAuthn (not just FIDO U2F)
4. Ensure `transports` are specified in `allowCredentials` or `excludeCredentials`:
   ```typescript
   allowCredentials: [{
     id: credentialId,
     type: 'public-key',
     transports: ['nfc', 'usb']  // Include all supported transports
   }]
   ```

### Invalid input errors

**Symptom**: `INVALID_INPUT` error when creating or authenticating

**Solutions**:
1. Verify `challenge` is valid base64url (no padding, uses `-` and `_`)
2. Check that `user.id` is valid base64url
3. Ensure `authenticatorAttachment` is either `"platform"`, `"cross-platform"`, or omitted
4. Validate that all credential IDs in `allowCredentials` are base64url encoded

### Operation timeout

**Symptom**: `TIMEOUT` error after specified duration

**Solutions**:
1. Increase timeout value in `publicKey.timeout` (default is 60 seconds):
   ```typescript
   publicKey: {
     timeout: 120000,  // 2 minutes in milliseconds
     // ... other options
   }
   ```
2. For security keys, ensure user is ready to interact with the key
3. Check if biometric sensor is responsive (for platform authenticators)
4. Verify no other app is blocking the Credential Manager UI
