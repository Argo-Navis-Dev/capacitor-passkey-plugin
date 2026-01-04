# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Capacitor Passkey Plugin - A cross-platform WebAuthn (Passkeys) implementation for Capacitor, enabling passwordless authentication using biometric and device credentials on iOS and Android.

## Commands

### Build & Development
- `npm run build` - Build the plugin (clean, generate docs, compile TypeScript, bundle with Rollup)
- `npm run clean` - Clean the dist directory
- `npm run watch` - Watch TypeScript files for changes

### Testing & Verification
- `npm run verify` - Run all platform verifications (iOS, Android, Web)
- `npm run verify:ios` - Build and verify iOS plugin
- `npm run verify:android` - Build and test Android plugin
- `npm run verify:web` - Build the web implementation

### Code Quality
- `npm run lint` - Run all linters (ESLint, Prettier check, SwiftLint)
- `npm run fmt` - Auto-fix code formatting (ESLint fix, Prettier write, SwiftLint fix)
- `npm run eslint` - Run ESLint on TypeScript files
- `npm run prettier` - Run Prettier on all supported files

### Documentation
- `npm run docgen` - Generate API documentation for README.md

## Architecture

### Plugin Structure
- **TypeScript/Web Layer** (`src/`):
  - `definitions.ts` - Core TypeScript interfaces for passkey operations
  - `index.ts` - Plugin registration and exports
  - `web.ts` - Web implementation fallback

- **iOS Implementation** (`ios/Sources/PasskeyPlugin/`):
  - Swift-based implementation using iOS 15+ Authentication Services
  - Handles passkey creation and authentication via native iOS APIs
  - Minimum iOS version: 15.0

- **Android Implementation** (`android/src/main/`):
  - Kotlin implementation using Android Credential Manager API
  - Supports Android 9.0+ (API Level 28+)
  - Uses coroutines for async operations

### Key Interfaces
- `PasskeyCreateOptions` - Options for creating new passkeys
- `PasskeyAuthenticationOptions` - Options for authenticating with existing passkeys
- Both interfaces follow WebAuthn specifications with base64url encoding for binary data

### Platform Integration
- Plugin registered as `PasskeyPlugin` in Capacitor
- Methods: `createPasskey` and `authenticate`
- All binary data (challenges, credential IDs, etc.) encoded as base64url strings for cross-platform compatibility

### Error Handling Architecture
All platforms use standardized error codes for consistent error handling:
- Error codes defined in `PasskeyPluginError.swift` (iOS), `PasskeyPlugin.kt` (Android), and `web.ts` (Web)
- Standard codes: `UNKNOWN_ERROR`, `CANCELLED`, `DOM_ERROR`, `UNSUPPORTED_ERROR`, `TIMEOUT`, `NO_CREDENTIAL`, `INVALID_INPUT`, `RPID_VALIDATION_ERROR`
- iOS: Uses `mapNSErrorToStandardCode()` to map native errors to standard codes
- Android: Uses `handleCreatePasskeyException()` and `handleAuthenticationError()` for exception mapping
- Web: Maps DOMException names to error codes in catch blocks

### iOS Implementation Details
- **Entry point**: `PasskeyPlugin.swift` - Capacitor plugin wrapper
- **Core logic**: `PasskeyPluginImpl.swift` - Handles WebAuthn operations
- **Delegate**: `PasskeyCredentialDelegate.swift` - ASAuthorization delegate with timeout support
- **Data models**: `PasskeyModels.swift` - Codable structs for WebAuthn options
- **rpId validation**: Validates against `com.apple.developer.web-credentials` in Info.plist
- **Authenticator selection**: Supports platform, cross-platform, or both based on `authenticatorAttachment`
- Uses `ASAuthorizationPlatformPublicKeyCredentialProvider` for biometric auth and `ASAuthorizationSecurityKeyPublicKeyCredentialProvider` for external keys

### Android Implementation Details
- **Single file**: `PasskeyPlugin.kt` contains all implementation
- **Coroutines**: Uses `CoroutineScope` with `Dispatchers.Main` for async operations
- **Timeout enforcement**: Uses `withTimeout()` to enforce timeout from options
- **Input validation**: Validates base64url format for challenges and credential IDs using `isValidBase64Url()`
- **Lifecycle**: Properly cancels coroutine scope in `handleOnDestroy()` to prevent leaks

### Base64url Encoding
- All platforms convert WebAuthn binary data (challenges, credential IDs, attestation objects, etc.) to/from base64url format
- Web: `base64urlToUint8Array()` and `toBase64url()` helper methods
- iOS: Uses `Data(base64URLEncoded:)` extension from `Data.swift`
- Android: Validates with regex and decodes using `Base64.decode()` after converting to standard base64