# Capacitor Passkey Plugin

A cross-platform Capacitor plugin that implements WebAuthn passkey creation and authentication for iOS, Android, and Web platforms. This plugin enables passwordless authentication using biometric and device credentials, providing a secure and seamless user experience across mobile apps and web browsers.

## Features

- **Full cross-platform support**: Native implementations for iOS, Android, and Web
- **Passkey creation**: Register new passkeys with biometric or device authentication
- **Passkey authentication**: Sign in users with existing passkeys
- **WebAuthn compatible**: Follows WebAuthn standards for credential management
- **Platform-optimized**: Uses iOS Keychain, Android Credential Manager API, and native browser WebAuthn
- **Unified API**: Same TypeScript interface works across all platforms

## Installation

```bash
npm install capacitor-passkey-plugin
npx cap sync
```

## Usage

```typescript
import { PasskeyPlugin } from 'capacitor-passkey-plugin';

// Create a new passkey
const credential = await PasskeyPlugin.createPasskey({
  publicKey: {
    challenge: 'base64url-encoded-challenge',
    rp: {
      id: 'example.com',
      name: 'Example App'
    },
    user: {
      id: 'base64url-encoded-user-id',
      name: 'user@example.com',
      displayName: 'User Name'
    },
    pubKeyCredParams: [
      { alg: -7, type: 'public-key' },
      { alg: -257, type: 'public-key' }
    ],
    authenticatorSelection: {
      authenticatorAttachment: 'platform',
      userVerification: 'required'
    },
    timeout: 60000,
    attestation: 'none'
  }
});

// Authenticate with an existing passkey
const authResult = await PasskeyPlugin.authenticate({
  publicKey: {
    challenge: 'base64url-encoded-challenge',
    rpId: 'example.com',
    timeout: 60000,
    userVerification: 'required',
    allowCredentials: [
      {
        id: 'base64url-encoded-credential-id',
        type: 'public-key',
        transports: ['internal']
      }
    ]
  }
});
```

## Platform Requirements

- **iOS**: iOS 15.0+ (uses Authentication Services framework)
- **Android**: API Level 28+ (Android 9.0+, uses Credential Manager API)
- **Web**: Modern browsers with WebAuthn support (Chrome 67+, Firefox 60+, Safari 14+)
- **Capacitor**: 6.0+

## Platform Configuration

### iOS

The iOS implementation automatically configures authenticator preferences based on your `authenticatorAttachment` setting:
- `"platform"` - Forces built-in authenticators (Touch ID, Face ID)
- `"cross-platform"` - Forces external security keys
- Omit the property - Allows both types (recommended)

Add your domain to `ios/App/App/Info.plist`:
```xml
<key>com.apple.developer.web-credentials</key>
<array>
    <string>yourdomain.com</string>
</array>
```

### Android

Add your domain configuration to `android/app/src/main/res/values/strings.xml`:
```xml
<string name="asset_statements" translatable="false">
[{
  "include": "https://yourdomain.com/.well-known/assetlinks.json"
}]
</string>
```

### Web

No additional configuration required. The plugin automatically uses the browser's native WebAuthn API when running in a web environment. Ensure your web server is configured with proper HTTPS and domain verification.

## Error Handling

All platforms use standardized error codes for consistent error handling across iOS, Android, and Web:

| Error Code | Description | Common Causes |
|------------|-------------|---------------|
| `UNKNOWN_ERROR` | Unexpected error occurred | Network issues, system errors |
| `CANCELLED` | User cancelled the operation | User dismissed the passkey prompt |
| `DOM_ERROR` | WebAuthn DOM exception | Invalid parameters, security constraints |
| `UNSUPPORTED_ERROR` | Operation not supported | Device doesn't support passkeys |
| `TIMEOUT` | Operation timed out | Exceeded specified timeout duration |
| `NO_CREDENTIAL` | No matching credential found | Authentication with non-existent passkey |
| `INVALID_INPUT` | Invalid input parameters | Missing required fields, malformed data |
| `RPID_VALIDATION_ERROR` | rpId validation failed (iOS) | rpId not in app's associated domains |

### Error Handling Example

```typescript
try {
  const result = await PasskeyPlugin.createPasskey(options);
  console.log('Success:', result);
} catch (error: any) {
  switch (error.code) {
    case 'CANCELLED':
      console.log('User cancelled passkey creation');
      break;
    case 'UNSUPPORTED_ERROR':
      console.log('Passkeys not supported on this device');
      break;
    case 'TIMEOUT':
      console.log('Operation timed out');
      break;
    case 'INVALID_INPUT':
      console.log('Invalid parameters provided');
      break;
    case 'RPID_VALIDATION_ERROR':
      console.log('Domain not configured in app settings');
      break;
    default:
      console.log('Unexpected error:', error.message);
  }
}
```