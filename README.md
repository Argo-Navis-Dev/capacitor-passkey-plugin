# Capacitor Passkey Plugin

A custom Capacitor plugin that implements WebAuthn passkey creation and authentication for both Android and iOS platforms. This plugin enables passwordless authentication using biometric and device credentials, providing a secure and seamless user experience for mobile applications.

## Features

- **Cross-platform support**: Native implementation for both Android and iOS
- **Passkey creation**: Register new passkeys with biometric or device authentication
- **Passkey authentication**: Sign in users with existing passkeys
- **WebAuthn compatible**: Follows WebAuthn standards for credential management
- **Secure storage**: Leverages platform-specific secure credential storage (Android Credential Manager API and iOS Keychain)

## Installation

```bash
npm install
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

- **Android**: API Level 28+ (Android 9.0+)
- **iOS**: iOS 15.0+
- **Capacitor**: 6.0+