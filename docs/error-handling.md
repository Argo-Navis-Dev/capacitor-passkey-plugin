# Error Handling Guide

This guide explains error handling in the Capacitor Passkey Plugin, including error codes and recommended handling strategies.

## Table of Contents

- [Error Codes](#error-codes)
- [Error Handling Patterns](#error-handling-patterns)
- [Recovery Strategies](#recovery-strategies)
- [Best Practices](#best-practices)

## Error Codes

All platforms use standardized error codes for consistent error handling:

| Error Code | Description | Common Causes | User Action |
|------------|-------------|---------------|-------------|
| `USER_CANCELLED` | User cancelled the operation | User pressed cancel, dismissed prompt | Retry or provide alternative |
| `TIMEOUT` | Operation timed out | Network slow, user inactive | Retry with longer timeout |
| `NOT_SUPPORTED` | Platform doesn't support passkeys | Old device, disabled features | Show fallback authentication |
| `NO_CREDENTIAL` | No matching credential found | Wrong domain, credential deleted | Register new passkey |
| `INVALID_INPUT` | Invalid parameters provided | Malformed challenge, missing data | Fix request format |
| `DOM_ERROR` | WebAuthn DOM exception | Security policy, origin mismatch | Check HTTPS, domain config |
| `UNKNOWN_ERROR` | Unexpected error occurred | Various platform issues | Generic error handling |

### Platform-Specific Notes

**Web**: Requires HTTPS (except localhost), maps from native `DOMException` types

**Android**: Requires Google Play Services, Android 9.0+ (API 28+), screen lock enabled

**iOS**: Requires iOS 15.0+, Face ID/Touch ID configured

## Error Handling Patterns

### Basic Error Handling

```typescript
async function handlePasskeyOperation() {
  try {
    const result = await PasskeyPlugin.createPasskey(options);
    // Handle success
    return result;
  } catch (error: any) {
    switch (error.code) {
      case 'USER_CANCELLED':
        // User cancelled - offer retry
        break;
      case 'NOT_SUPPORTED':
        // Use fallback authentication
        break;
      case 'NO_CREDENTIAL':
        // Offer to register new passkey
        break;
      default:
        // Generic error handling
        console.error('Passkey error:', error);
    }
  }
}
```

### Error Response Format

```typescript
interface PasskeyError {
  code: string;        // Standardized error code
  message: string;     // Human-readable description
  platform?: string;   // Platform where error occurred
}
```

## Recovery Strategies

### Graceful Degradation

```typescript
class AuthenticationManager {
  async authenticate(): Promise<AuthResult> {
    try {
      // Try passkey first
      return await PasskeyPlugin.authenticate(options);
    } catch (error: any) {
      // Fallback based on error
      switch (error.code) {
        case 'NOT_SUPPORTED':
          return this.usePasswordAuth();

        case 'NO_CREDENTIAL':
          return this.offerRegistration();

        case 'USER_CANCELLED':
          return this.showAuthOptions();

        default:
          return this.usePasswordAuth();
      }
    }
  }
}
```

### Retry with Exponential Backoff

```typescript
async function retryOperation<T>(
  operation: () => Promise<T>,
  maxAttempts: number = 3
): Promise<T> {
  const nonRetryableCodes = [
    'USER_CANCELLED',
    'NOT_SUPPORTED',
    'NO_CREDENTIAL',
    'INVALID_INPUT'
  ];

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error: any) {
      // Don't retry certain errors
      if (nonRetryableCodes.includes(error.code)) {
        throw error;
      }

      // Last attempt - throw error
      if (attempt === maxAttempts) {
        throw error;
      }

      // Wait before retry (exponential backoff)
      const delay = 1000 * Math.pow(2, attempt - 1);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw new Error('Max attempts reached');
}
```

### Platform-Specific Handling

```typescript
function handlePlatformError(error: PasskeyError) {
  const platform = Capacitor.getPlatform();

  if (platform === 'web' && error.code === 'DOM_ERROR') {
    // Check HTTPS requirement
    if (location.protocol !== 'https:' && location.hostname !== 'localhost') {
      return 'Passkeys require HTTPS connection';
    }
  }

  if (platform === 'android' && error.code === 'NOT_SUPPORTED') {
    return 'Please update Google Play Services';
  }

  if (platform === 'ios' && error.code === 'NOT_SUPPORTED') {
    return 'Please enable Face ID/Touch ID in Settings';
  }

  return error.message;
}
```

## Best Practices

1. **Always provide fallback authentication** - Don't rely solely on passkeys
2. **Handle errors gracefully** - Show user-friendly messages
3. **Log errors for debugging** - But never log sensitive data
4. **Implement retry logic** - For transient errors only
5. **Test error scenarios** - Don't assume happy path
6. **Monitor error rates** - Track authentication success/failure

### Testing Error Scenarios

```typescript
// Test timeout handling
await PasskeyPlugin.createPasskey({
  publicKey: { ...options, timeout: 1 }
});

// Test invalid input
await PasskeyPlugin.createPasskey({
  publicKey: { challenge: 'invalid-base64!' }
});

// Test with wrong domain
await PasskeyPlugin.authenticate({
  publicKey: { rpId: 'wrong-domain.com' }
});
```

### User-Friendly Error Messages

```typescript
function getUserMessage(error: PasskeyError): string {
  const messages = {
    'USER_CANCELLED': 'Authentication cancelled. Please try again.',
    'TIMEOUT': 'Request timed out. Please try again.',
    'NOT_SUPPORTED': 'Passkeys not supported on this device.',
    'NO_CREDENTIAL': 'No passkey found. Please register first.',
    'INVALID_INPUT': 'Invalid request. Please contact support.',
    'DOM_ERROR': 'Security error. Check your connection.',
    'UNKNOWN_ERROR': 'Something went wrong. Please try again.'
  };

  return messages[error.code] || messages['UNKNOWN_ERROR'];
}
```

## Related Documentation

- [Integration Guide](./integration-guide.md) - Setup and basic usage
- [Architecture Guide](./architecture.md) - Error handling implementation details