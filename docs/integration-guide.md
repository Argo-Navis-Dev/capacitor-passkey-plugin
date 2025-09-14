# Integration Guide

Step-by-step guide for integrating the Capacitor Passkey Plugin into your Capacitor project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [TypeScript Implementation](#typescript-implementation)
- [Platform Configuration](#platform-configuration)
  - [Android Setup](#android-setup)
  - [iOS Setup](#ios-setup)
- [Domain Association Files](#domain-association-files)
- [Building and Deployment](#building-and-deployment)
- [Testing](#testing)

## Prerequisites

- **Capacitor project** already initialized
- **Node.js**: 18.0.0 or higher
- **Capacitor**: 7.0.0 or higher
- **TypeScript**: 5.0.0 or higher (recommended)

### Platform Requirements

- **Web**: Modern browser with WebAuthn support
- **Android**: API Level 28+ (Android 9.0+), Android Studio
- **iOS**: iOS 15.0+, Xcode 14+, macOS for development

## Installation

1. **Install the plugin in your Capacitor project:**
```bash
npm install capacitor-passkey-plugin
```

2. **Sync the plugin with native platforms:**
```bash
npx cap sync
```

This copies the plugin to both Android and iOS projects.

## TypeScript Implementation

First, implement the passkey functionality in your TypeScript/JavaScript code before configuring native platforms.

### 1. Create a Passkey Service

Create `src/services/passkey.service.ts`:

```typescript
import { PasskeyPlugin } from 'capacitor-passkey-plugin';

export class PasskeyService {
  private rpId = 'your-domain.com'; // Your domain
  private rpName = 'Your App Name';

  async register(userId: string, userName: string): Promise<any> {
    try {
      // Get challenge from your backend
      const challenge = await this.getChallengeFromServer();

      const result = await PasskeyPlugin.createPasskey({
        publicKey: {
          challenge: challenge,
          rp: {
            id: this.rpId,
            name: this.rpName
          },
          user: {
            id: this.base64urlEncode(userId),
            name: userName,
            displayName: userName
          },
          pubKeyCredParams: [
            { alg: -7, type: 'public-key' },   // ES256
            { alg: -257, type: 'public-key' }  // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required'
          },
          timeout: 60000,
          attestation: 'none'
        }
      });

      // Send to backend for verification and storage
      await this.verifyWithServer('register', result);
      return result;

    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  async authenticate(): Promise<any> {
    try {
      const challenge = await this.getChallengeFromServer();

      const result = await PasskeyPlugin.authenticate({
        publicKey: {
          challenge: challenge,
          rpId: this.rpId,
          timeout: 60000,
          userVerification: 'required'
        }
      });

      // Verify with backend
      await this.verifyWithServer('authenticate', result);
      return result;

    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  private handleError(error: any) {
    switch (error.code) {
      case 'USER_CANCELLED':
        console.log('User cancelled');
        break;
      case 'NOT_SUPPORTED':
        console.log('Device does not support passkeys');
        break;
      case 'NO_CREDENTIAL':
        console.log('No passkey found');
        break;
      default:
        console.error('Passkey error:', error);
    }
  }

  private base64urlEncode(str: string): string {
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  private async getChallengeFromServer(): Promise<string> {
    // Implement your server API call
    const response = await fetch('https://your-api.com/auth/challenge');
    const data = await response.json();
    return data.challenge;
  }

  private async verifyWithServer(type: string, credential: any): Promise<void> {
    // Implement your server verification
    await fetch(`https://your-api.com/auth/${type}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credential)
    });
  }
}
```

### 2. Use in Your App Component

```typescript
import { PasskeyService } from './services/passkey.service';

export class AuthComponent {
  private passkeyService = new PasskeyService();

  async onRegister() {
    try {
      await this.passkeyService.register('user123', 'john@example.com');
      console.log('Passkey registered successfully');
    } catch (error) {
      console.error('Registration failed:', error);
    }
  }

  async onLogin() {
    try {
      await this.passkeyService.authenticate();
      console.log('Authentication successful');
    } catch (error) {
      console.error('Authentication failed:', error);
    }
  }
}
```

## Platform Configuration

After implementing in TypeScript, configure each platform:

### Android Setup

1. **Sync Android project:**
```bash
npx cap sync android
```

2. **Open Android project:**
```bash
npx cap open android
```

3. **Update `android/app/build.gradle`:**
```gradle
android {
    compileSdkVersion 35
    defaultConfig {
        minSdkVersion 28
        targetSdkVersion 35
    }
}

dependencies {
    implementation 'androidx.credentials:credentials:1.5.0'
    implementation 'androidx.credentials:credentials-play-services-auth:1.5.0'
}
```

4. **Requirements:**
- Physical device with Android 9.0+
- Google Play Services updated
- Screen lock enabled

### iOS Setup

1. **Sync iOS project:**
```bash
npx cap sync ios
```

2. **Open iOS project:**
```bash
npx cap open ios
```

3. **In Xcode, configure Associated Domains:**
- Select your app target
- Go to "Signing & Capabilities" tab
- Add "Associated Domains" capability
- Add: `webcredentials:your-domain.com`

4. **Update `Info.plist` if using Face ID:**
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to authenticate with passkeys</string>
```

5. **Requirements:**
- Physical device with iOS 15.0+
- Face ID/Touch ID configured

## Domain Association Files

Deploy these files to your web server before testing on devices:

### Android: `/.well-known/assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.yourcompany.yourapp",
      "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
    }
  }
]
```

Get SHA256 fingerprint:
```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release
keytool -list -v -keystore your-release.keystore -alias your-alias
```

### iOS: `/apple-app-site-association`

```json
{
  "webcredentials": {
    "apps": ["TEAMID.com.yourcompany.yourapp"]
  }
}
```

Find Team ID in Apple Developer account → Membership.

### Hosting Requirements

- **HTTPS with valid certificate**
- **Content-Type: application/json**
- **HTTP 200 (no redirects)**
- **Publicly accessible**

Upload these JSON files to your web server root or `.well-known` directory.

## Building and Deployment

### Development Build

1. **Build your web app:**
```bash
npm run build
```

2. **Copy web assets to native platforms:**
```bash
npx cap copy
```

3. **Run on Android:**
```bash
npx cap run android
```

4. **Run on iOS:**
```bash
npx cap run ios
```

### Production Build

1. **Build optimized web app:**
```bash
npm run build --prod
```

2. **Sync all platforms:**
```bash
npx cap sync
```

3. **Android Release:**
```bash
cd android
./gradlew assembleRelease
# or
./gradlew bundleRelease  # for AAB
```

4. **iOS Release:**
- Open in Xcode: `npx cap open ios`
- Select "Any iOS Device" as target
- Product → Archive
- Distribute to App Store

## Testing

### Local Testing Workflow

1. **Web Testing:**
```bash
npm run serve
# Test at http://localhost:8100
```

2. **Android Device Testing:**
```bash
# Connect device via USB
adb devices  # Verify device connected
npx cap run android --target [device-id]
```

3. **iOS Device Testing:**
```bash
# Connect iPhone/iPad
npx cap run ios --target [device-id]
```

### Debugging

**Android:**
- Use Chrome DevTools: `chrome://inspect`
- Check Logcat in Android Studio

**iOS:**
- Use Safari Web Inspector
- Xcode console for native logs

### Verification Checklist

- [ ] TypeScript implementation complete
- [ ] `npx cap sync` executed for both platforms
- [ ] Domain association files deployed
- [ ] Android minimum SDK verified
- [ ] iOS entitlements configured
- [ ] Physical devices ready for testing
- [ ] Backend API endpoints ready

## Common Issues

**"Plugin not found"**
- Run `npx cap sync` after installation

**"Not supported" error**
- Verify device meets minimum requirements
- Check if screen lock/biometrics enabled

**"Domain association failed"**
- Verify files are accessible via HTTPS
- Check correct Team ID/SHA256 fingerprint

## Next Steps

- [Error Handling Guide](./error-handling.md) - Handle errors gracefully
- [Architecture Guide](./architecture.md) - Understand plugin internals

## Support

- [GitHub Issues](https://github.com/Argo-Navis-Dev/capacitor-passkey-plugin/issues)
- [Capacitor Documentation](https://capacitorjs.com/docs)