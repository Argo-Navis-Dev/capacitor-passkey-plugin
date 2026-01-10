# Web Platform Guide

This guide covers Web-specific configuration, requirements, and implementation details for the Capacitor Passkey Plugin.

## Requirements

### Browser Support

| Browser | Minimum Version |
|---------|-----------------|
| Chrome  | 67+             |
| Firefox | 60+             |
| Safari  | 14+             |
| Edge    | 79+             |

### Server Requirements

- HTTPS is required (WebAuthn does not work over HTTP, except localhost)
- Valid SSL certificate
- Proper CORS configuration if using cross-origin requests

## Configuration

### No Plugin Configuration Required

The web implementation uses the browser's native WebAuthn API directly. No additional plugin configuration is needed.

### Server Setup

Your server must be accessible over HTTPS and the `rpId` must match your domain:

```typescript
const credential = await PasskeyPlugin.createPasskey({
  publicKey: {
    rp: {
      id: 'yourdomain.com',  // Must match your actual domain
      name: 'Your App Name'
    },
    // ... other options
  }
});
```

## Authenticator Selection

The web implementation supports all WebAuthn authenticator types:

| Value | Behavior |
|-------|----------|
| `"platform"` | Uses device's built-in authenticators |
| `"cross-platform"` | Uses external security keys |
| Not specified | Allows both types |

### Platform Authenticators

Platform authenticators vary by device and browser:
- **macOS**: Touch ID, Apple Watch
- **Windows**: Windows Hello (fingerprint, face, PIN)
- **iOS Safari**: Face ID, Touch ID
- **Android Chrome**: Fingerprint, face unlock

### Security Keys

External FIDO2 security keys are widely supported:
- USB security keys (YubiKey, etc.)
- NFC keys (on supported devices)
- Bluetooth keys

## Implementation Details

### Native WebAuthn API

The web implementation is a thin wrapper around the browser's WebAuthn API:
- `navigator.credentials.create()` for passkey creation
- `navigator.credentials.get()` for authentication

### Base64url Encoding

The plugin handles base64url encoding/decoding automatically:
- Input challenges and credential IDs are decoded from base64url
- Output attestation objects and signatures are encoded to base64url

### Timeout Handling

The browser enforces the timeout specified in options. The plugin passes the timeout directly to the WebAuthn API.

## Error Codes

Web-specific error mappings from DOMException:

| Error Code | DOMException Name | Description |
|------------|-------------------|-------------|
| `CANCELLED` | `AbortError` | User cancelled or operation aborted |
| `CANCELLED` | `NotAllowedError` | User denied or cancelled |
| `UNSUPPORTED_ERROR` | `NotSupportedError` | WebAuthn not supported |
| `INVALID_INPUT` | `TypeError` | Invalid parameters |
| `INVALID_INPUT` | `SecurityError` | Security constraint violation |
| `TIMEOUT` | `TimeoutError` | Operation timed out |
| `NO_CREDENTIAL` | No credentials returned | No matching credential |
| `DOM_ERROR` | Other DOMExceptions | Other WebAuthn errors |

## Browser-Specific Notes

### Chrome

- Full WebAuthn support since version 67
- Supports platform authenticators via Chrome's built-in password manager
- Passkeys sync across devices when signed into Chrome

### Firefox

- WebAuthn support since version 60
- Platform authenticator support varies by OS
- Security key support is excellent

### Safari

- WebAuthn support since Safari 14
- Excellent integration with iCloud Keychain for passkey sync
- Touch ID and Face ID support on macOS and iOS

### Edge

- Full WebAuthn support since version 79 (Chromium-based)
- Windows Hello integration on Windows
- Shares passkey sync with Chrome when using same account

## Troubleshooting

### "WebAuthn is not supported" error

1. Ensure you're using HTTPS (or localhost for development)
2. Check browser version meets minimum requirements
3. Verify `navigator.credentials` is available

### "NotAllowedError" when creating passkey

1. User may have cancelled the operation
2. Check that the page is in a secure context (HTTPS)
3. Ensure the rpId matches your domain
4. Verify user gesture is present (some browsers require user interaction)

### "SecurityError" during authentication

1. Verify the rpId matches the domain where the passkey was created
2. Check that you're using HTTPS
3. Ensure no iframe restrictions are blocking WebAuthn

### Passkeys not syncing between devices

1. Check that the user is signed into their browser account
2. Verify passkey sync is enabled in browser settings
3. Note that passkeys created with `authenticatorAttachment: 'cross-platform'` won't sync

## Development Tips

### Local Development

WebAuthn works on `localhost` without HTTPS:

```typescript
// Works in development
const credential = await PasskeyPlugin.createPasskey({
  publicKey: {
    rp: {
      id: 'localhost',
      name: 'Dev App'
    },
    // ...
  }
});
```

### Feature Detection

Check for WebAuthn support before using the plugin:

```typescript
if (window.PublicKeyCredential) {
  // WebAuthn is supported
  const credential = await PasskeyPlugin.createPasskey(options);
} else {
  // Fall back to password authentication
}
```

### Conditional UI (Chrome 108+)

For a seamless experience, you can check if conditional UI is available:

```typescript
if (window.PublicKeyCredential?.isConditionalMediationAvailable) {
  const available = await PublicKeyCredential.isConditionalMediationAvailable();
  if (available) {
    // Can use conditional UI for smoother UX
  }
}
```
