# Architecture Guide

This guide explains the internal architecture of the Capacitor Passkey Plugin, how it works across platforms, and design decisions made during development.

## Table of Contents

- [Overview](#overview)
- [Plugin Architecture](#plugin-architecture)
- [Platform Implementations](#platform-implementations)
- [Data Flow](#data-flow)
- [Security Considerations](#security-considerations)
- [Performance Design](#performance-design)
- [Error Handling Architecture](#error-handling-architecture)
- [Future Enhancements](#future-enhancements)

## Overview

The Capacitor Passkey Plugin provides a unified interface for WebAuthn passkey operations across Web, Android, and iOS platforms. It abstracts platform-specific implementations while maintaining consistent behavior and error handling.

### Design Goals

1. **Cross-platform consistency** - Same API and behavior everywhere
2. **WebAuthn compliance** - Follow W3C WebAuthn specifications
3. **Security first** - No sensitive data in logs, proper validation
4. **Performance** - Efficient memory usage, proper lifecycle management
5. **Developer experience** - Clear errors, comprehensive documentation

### High-Level Architecture

```
┌─────────────────┐
│   Application   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  Plugin Interface│  ← TypeScript definitions
│  (definitions.ts)│
└─────────────────┘
         │
    ┌────┼────┐
    ▼    ▼    ▼
┌─────┐ ┌─────┐ ┌─────┐
│ Web │ │Android│ │ iOS │  ← Platform implementations
└─────┘ └─────┘ └─────┘
    │       │       │
    ▼       ▼       ▼
┌─────┐ ┌─────┐ ┌─────┐
│WebAuthn│Credential│Auth │  ← Platform APIs
│  API   │Manager│Services│
└─────┘ └─────┘ └─────┘
```

## Plugin Architecture

### Core Components

#### 1. TypeScript Interface (`src/definitions.ts`)
Defines the contract that all platform implementations must follow:

```typescript
export interface PasskeyPlugin {
  createPasskey(options: PasskeyCreateOptions): Promise<PasskeyCreateResult>;
  authenticate(options: PasskeyAuthenticationOptions): Promise<PasskeyAuthResult>;
}
```

**Key Design Decisions**:
- **Base64url encoding** for binary data (cross-platform compatibility)
- **WebAuthn-compliant** parameter names and structures
- **Promise-based** API for async operations
- **Strongly typed** interfaces for better developer experience

#### 2. Plugin Registration (`src/index.ts`)
```typescript
import { registerPlugin } from '@capacitor/core';
const PasskeyPlugin = registerPlugin<PasskeyPlugin>('PasskeyPlugin', {
  web: () => import('./web').then(m => new m.WebPasskeyPlugin()),
});
```

**Registration Strategy**:
- **Lazy loading** - Web implementation loaded only when needed
- **Automatic platform detection** - Capacitor handles platform routing
- **Fallback handling** - Web implementation available everywhere

## Platform Implementations

### Web Implementation (`src/web.ts`)

**Architecture**:
```
WebPasskeyPlugin extends WebPlugin
├── createPasskey() ────┐
├── authenticate() ─────┼─► Error handling wrapper
├── Helper methods ─────┘    ├── Input validation
   ├── base64url conversion  ├── Timeout enforcement
   ├── Format conversion     ├── Error categorization
   └── Validation utilities  └── Logging
```

**Key Components**:

1. **Format Converters**:
   - `toPublicKeyCredentialCreationOptions()` - Plugin format → WebAuthn API
   - `toPublicKeyCredentialRequestOptions()` - Plugin format → WebAuthn API
   - `base64urlToUint8Array()` / `toBase64url()` - Encoding utilities

2. **Error Handling**:
   - Maps `DOMException` types to standardized error codes
   - Provides timeout enforcement via `Promise.race()`
   - Validates input parameters before API calls

3. **Safety Features**:
   - Stack overflow prevention in base64 encoding
   - Input validation for required parameters
   - Browser compatibility checks

### Android Implementation (`android/.../PasskeyPlugin.kt`)

**Architecture**:
```
PasskeyPlugin extends Plugin
├── Lifecycle Management ───┐
│   ├── load()              │
│   └── handleOnDestroy()   │
├── Core Methods ───────────┼─► Coroutine-based async execution
│   ├── createPasskey()     │   ├── Timeout enforcement
│   └── authenticate()      │   ├── Input validation
├── Error Handling ─────────┘   ├── Exception mapping
│   ├── handleCreatePasskeyException()
│   ├── handleAuthenticationError()
│   └── handlePluginError()
└── Utilities
    ├── isValidBase64Url()
    └── Error code constants
```

**Key Components**:

1. **Coroutine Management**:
   ```kotlin
   class PasskeyPlugin : Plugin() {
       private var mainScope: CoroutineScope? = null

       override fun load() {
           mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
       }

       override fun handleOnDestroy() {
           mainScope?.cancel()  // Prevent memory leaks
           mainScope = null
       }
   }
   ```

2. **Timeout Implementation**:
   ```kotlin
   mainScope?.launch {
       try {
           withTimeout(timeout) {
               // Credential operations
           }
       } catch (e: TimeoutCancellationException) {
           handlePluginError(call, ErrorCodes.TIMEOUT, "Operation timed out")
       }
   }
   ```

3. **Exception Mapping**:
   - `CreateCredentialException` → Plugin error codes
   - `GetCredentialException` → Plugin error codes
   - Consistent error messages across operations

### iOS Implementation (`ios/Sources/PasskeyPlugin/`)

**Architecture**:
```
PasskeyPlugin (CAPPlugin)
├── PasskeyPlugin.swift ────┐
│   ├── createPasskey()     │
│   └── authenticate()      │
├── PasskeyPluginImpl.swift ┼─► Core implementation
│   ├── Platform operations │   ├── Async/await pattern
│   └── Error handling      │   ├── Delegate pattern
├── PasskeyModels.swift ────┘   └── Swift Codable models
├── PasskeyPluginError.swift
└── PasskeyCredentialDelegate.swift
```

**Key Components**:

1. **Separation of Concerns**:
   - `PasskeyPlugin.swift` - Capacitor bridge layer
   - `PasskeyPluginImpl.swift` - Core passkey operations
   - `PasskeyCredentialDelegate.swift` - AuthenticationServices delegate

2. **Error Handling**:
   ```swift
   enum PasskeyPluginErrorCode: String {
       case missingPublicKeyCreate = "-100"
       case passkeyCreationFailed = "-102"
       // Note: These will be updated to match other platforms
   }
   ```

3. **Async Pattern**:
   ```swift
   @objc func createPasskey(_ call: CAPPluginCall) {
       Task {
           do {
               let result = try await implementation.createPasskey(publicKeyData)
               call.resolve(result)
           } catch {
               // Error handling
           }
       }
   }
   ```

## Data Flow

### Passkey Creation Flow

```
Application
    │ createPasskey(options)
    ▼
Plugin Interface
    │ Validate options
    ▼
Platform Implementation
    │ ┌─── Web: navigator.credentials.create()
    ├─┼─── Android: CredentialManager.createCredential()
    │ └─── iOS: ASAuthorizationController
    ▼
Platform API
    │ User interaction (biometric, device auth)
    ▼
Credential Created
    │ Platform-specific response
    ▼
Response Transformation
    │ Convert to standardized format
    │ Encode binary data as base64url
    ▼
Application
    │ PasskeyCreateResult
```

### Authentication Flow

```
Application
    │ authenticate(options)
    ▼
Plugin Interface
    │ Validate challenge, rpId
    ▼
Platform Implementation
    │ ┌─── Web: navigator.credentials.get()
    ├─┼─── Android: CredentialManager.getCredential()
    │ └─── iOS: ASAuthorizationController
    ▼
Platform API
    │ User interaction (biometric verification)
    ▼
Assertion Generated
    │ Cryptographic signature
    ▼
Response Transformation
    │ Convert to standardized format
    │ Encode signature, authenticator data
    ▼
Application
    │ PasskeyAuthResult
```

### Error Flow

```
Platform Error
    │ Platform-specific exception
    ▼
Error Mapping
    │ Map to standardized error code
    │ Create consistent error message
    ▼
Error Logging
    │ Log for debugging (no sensitive data)
    ▼
Plugin Interface
    │ Throw standardized error
    ▼
Application
    │ Handle error with consistent code
```
