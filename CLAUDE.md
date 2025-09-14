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