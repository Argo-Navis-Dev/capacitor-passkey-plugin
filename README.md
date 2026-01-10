# Capacitor Passkey Plugin

A cross-platform Capacitor plugin that implements WebAuthn passkey creation and authentication for iOS, Android, and Web platforms. This plugin enables passwordless authentication using biometric and device credentials, providing a secure and seamless user experience across mobile apps and web browsers.

## Features

- **Full cross-platform support**: Native implementations for iOS, Android, and Web
- **Passkey creation**: Register new passkeys with biometric or device authentication
- **Passkey authentication**: Sign in users with existing passkeys
- **YubiKey & security key support**: External FIDO2 authenticators
- **WebAuthn compatible**: Follows WebAuthn standards for credential management
- **Platform-optimized**: Uses iOS Keychain, Android Credential Manager API, and native browser WebAuthn
- **Unified API**: Same TypeScript interface works across all platforms

## Installation

```bash
npm install capacitor-passkey-plugin
npx cap sync
```

## Quick Start

```typescript
import { PasskeyPlugin } from 'capacitor-passkey-plugin';

// Create a new passkey
const credential = await PasskeyPlugin.createPasskey({
  publicKey: {
    challenge: 'base64url-encoded-challenge',
    rp: { id: 'example.com', name: 'Example App' },
    user: {
      id: 'base64url-encoded-user-id',
      name: 'user@example.com',
      displayName: 'User Name'
    },
    pubKeyCredParams: [
      { alg: -7, type: 'public-key' },
      { alg: -257, type: 'public-key' }
    ],
    timeout: 60000
  }
});

// Authenticate with an existing passkey
const authResult = await PasskeyPlugin.authenticate({
  publicKey: {
    challenge: 'base64url-encoded-challenge',
    rpId: 'example.com',
    timeout: 60000
  }
});
```

## Requirements

| Platform | Minimum Version | Notes |
|----------|-----------------|-------|
| iOS      | 15.0            | Face ID, YubiKey (tested) |
| Android  | 9.0 (API 28)    | Credential Manager API |
| Web      | Modern browsers | Chrome 67+, Firefox 60+, Safari 14+, Edge 79+ |
| Capacitor | 8.0.0          | Required |
| Node.js  | 18.0.0          | For development |

## Error Handling

All platforms use standardized error codes:

| Error Code | Description |
|------------|-------------|
| `CANCELLED` | User cancelled the operation |
| `UNSUPPORTED_ERROR` | Passkeys not supported on device |
| `TIMEOUT` | Operation timed out |
| `NO_CREDENTIAL` | No matching credential found |
| `INVALID_INPUT` | Invalid parameters provided |
| `RPID_VALIDATION_ERROR` | Domain not configured (iOS) |

```typescript
try {
  const result = await PasskeyPlugin.createPasskey(options);
} catch (error: any) {
  switch (error.code) {
    case 'CANCELLED':
      // User cancelled
      break;
    case 'UNSUPPORTED_ERROR':
      // Device doesn't support passkeys
      break;
    default:
      // Handle other errors
  }
}
```

## Platform Guides

For detailed platform-specific configuration and troubleshooting:

- **[iOS Guide](docs/ios.md)** - Associated Domains, Face ID/Touch ID, YubiKey setup
- **[Android Guide](docs/android.md)** - Digital Asset Links, Credential Manager
- **[Web Guide](docs/web.md)** - Browser support, HTTPS requirements

## Additional Documentation

- [Architecture Overview](docs/architecture.md)
- [Error Handling Guide](docs/error-handling.md)
- [Integration Guide](docs/integration-guide.md)

## DeepWiki

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](http://deepwiki.com/Argo-Navis-Dev/capacitor-passkey-plugin/)
