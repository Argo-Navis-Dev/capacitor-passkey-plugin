import { WebPlugin } from '@capacitor/core';

import type {
  PasskeyPlugin,
  PasskeyCreateOptions,
  PasskeyCreateResult,
  PublicKeyCreationOptions,
  PasskeyAuthResult,
  PasskeyAuthenticationOptions,
  PublicKeyAuthenticationOptions,
} from './definitions';

/**
 * Web implementation of the PasskeyPlugin using WebAuthn API
 * Provides passkey creation and authentication for web browsers
 * Handles base64url encoding/decoding and error standardization
 */
export class WebPasskeyPlugin extends WebPlugin implements PasskeyPlugin {
  // Match Android error codes for consistency
  private readonly ErrorCodes = {
    UNKNOWN: 'UNKNOWN_ERROR',
    CANCELLED: 'CANCELLED',
    DOM: 'DOM_ERROR',
    UNSUPPORTED: 'UNSUPPORTED_ERROR',
    TIMEOUT: 'TIMEOUT',
    NO_CREDENTIAL: 'NO_CREDENTIAL',
  };

  /**
   * Creates a new passkey credential for user authentication
   * @param options - Contains publicKey parameters following WebAuthn spec
   * @returns Promise resolving to credential creation result with attestation
   * @throws Error with code if creation fails or is cancelled by user
   */
  async createPasskey(options: PasskeyCreateOptions): Promise<PasskeyCreateResult> {
    try {
      if (!('credentials' in navigator) || typeof navigator.credentials.create !== 'function') {
        const error = new Error('PasskeyPlugin not supported in this browser');
        (error as any).code = this.ErrorCodes.UNSUPPORTED;
        throw error;
      }

      // Basic input validation
      if (!options?.publicKey) {
        const error = new Error('Missing publicKey parameter');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }

      const crossPlatformOptions = options.publicKey as PublicKeyCreationOptions;

      if (!crossPlatformOptions.challenge || !crossPlatformOptions.user?.id) {
        const error = new Error('Missing required parameters: challenge or user.id');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }
      const webPasskeyOptions = this.toPublicKeyCredentialCreationOptions(crossPlatformOptions);

      // Add timeout handling
      let credential: PublicKeyCredential;
      const timeout = crossPlatformOptions.timeout || 60000;

      const credentialPromise = navigator.credentials.create({
        publicKey: webPasskeyOptions,
      }) as Promise<PublicKeyCredential>;

      if (timeout > 0) {
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => {
            const error = new Error(`Operation timed out after ${timeout}ms`);
            (error as any).code = this.ErrorCodes.TIMEOUT;
            reject(error);
          }, timeout);
        });
        credential = await Promise.race([credentialPromise, timeoutPromise]);
      } else {
        credential = await credentialPromise;
      }

      if (!credential) {
        const error = new Error('Credential creation failed');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }
      const attestationResponse = credential.response as AuthenticatorAttestationResponse;
      if (credential.response instanceof AuthenticatorAttestationResponse) {
        return {
          id: credential.id,
          rawId: this.toBase64url(new Uint8Array(credential.rawId)),
          response: {
            attestationObject: this.toBase64url(new Uint8Array(attestationResponse.attestationObject)),
            clientDataJSON: this.toBase64url(new Uint8Array(attestationResponse.clientDataJSON)),
          },
        };
      } else {
        const error = new Error('Unsupported response type');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }
    } catch (error: any) {
      // Map DOMException to Android error codes
      if (!error.code && error.name) {
        switch (error.name) {
          case 'NotAllowedError':
          case 'AbortError':
            error.code = this.ErrorCodes.CANCELLED;
            break;
          case 'SecurityError':
            error.code = this.ErrorCodes.DOM;
            break;
          case 'NotSupportedError':
            error.code = this.ErrorCodes.UNSUPPORTED;
            break;
          default:
            error.code = error.code || this.ErrorCodes.UNKNOWN;
        }
      }
      console.error('Passkey registration failed:', error.message, 'Code:', error.code);
      throw error;
    }
  }

  /**
   * Authenticates user with an existing passkey
   * @param options - Contains publicKey parameters for authentication challenge
   * @returns Promise resolving to authentication assertion with signature
   * @throws Error with code if authentication fails or no credential found
   */
  async authenticate(options: PasskeyAuthenticationOptions): Promise<PasskeyAuthResult> {
    try {
      if (!('credentials' in navigator) || typeof navigator.credentials.get !== 'function') {
        const error = new Error('PasskeyPlugin not supported in this browser');
        (error as any).code = this.ErrorCodes.UNSUPPORTED;
        throw error;
      }

      // Basic input validation
      if (!options?.publicKey) {
        const error = new Error('Missing publicKey parameter');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }

      const crossPlatformOptions = options.publicKey as PublicKeyAuthenticationOptions;

      if (!crossPlatformOptions.challenge) {
        const error = new Error('Missing required challenge parameter');
        (error as any).code = this.ErrorCodes.UNKNOWN;
        throw error;
      }
      const nativeOptions = this.toPublicKeyCredentialRequestOptions(
        crossPlatformOptions,
      ) as PublicKeyCredentialRequestOptions;
      // Add timeout handling
      let publicKeyCredential: PublicKeyCredential;
      const timeout = crossPlatformOptions.timeout || 60000;

      const credentialPromise = navigator.credentials.get({
        publicKey: nativeOptions,
      }) as Promise<PublicKeyCredential>;

      if (timeout > 0) {
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => {
            const error = new Error(`Operation timed out after ${timeout}ms`);
            (error as any).code = this.ErrorCodes.TIMEOUT;
            reject(error);
          }, timeout);
        });
        publicKeyCredential = await Promise.race([credentialPromise, timeoutPromise]);
      } else {
        publicKeyCredential = await credentialPromise;
      }
      if (!publicKeyCredential) {
        const error = new Error('No credential found');
        (error as any).code = this.ErrorCodes.NO_CREDENTIAL;
        throw error;
      }
      const assertionResponse = publicKeyCredential.response as AuthenticatorAssertionResponse;
      return {
        id: publicKeyCredential.id,
        rawId: this.toBase64url(new Uint8Array(publicKeyCredential.rawId)),
        type: publicKeyCredential.type,
        response: {
          clientDataJSON: this.toBase64url(new Uint8Array(assertionResponse.clientDataJSON)),
          authenticatorData: this.toBase64url(new Uint8Array(assertionResponse.authenticatorData)),
          signature: this.toBase64url(new Uint8Array(assertionResponse.signature)),
          userHandle: assertionResponse.userHandle
            ? this.toBase64url(new Uint8Array(assertionResponse.userHandle))
            : undefined,
        },
      };
    } catch (error: any) {
      // Map DOMException to Android error codes
      if (!error.code && error.name) {
        switch (error.name) {
          case 'NotAllowedError':
          case 'AbortError':
            error.code = this.ErrorCodes.CANCELLED;
            break;
          case 'SecurityError':
            error.code = this.ErrorCodes.DOM;
            break;
          case 'NotSupportedError':
            error.code = this.ErrorCodes.UNSUPPORTED;
            break;
          default:
            error.code = error.code || this.ErrorCodes.UNKNOWN;
        }
      }
      console.error('Passkey authentication failed:', error.message, 'Code:', error.code);
      throw error;
    }
  }

  /**
   * Converts plugin format to WebAuthn API format for credential creation
   * Transforms base64url encoded strings to Uint8Arrays as required by WebAuthn
   * @param safe - Creation options with base64url encoded binary fields
   * @returns Native WebAuthn creation options with Uint8Array fields
   */
  toPublicKeyCredentialCreationOptions(safe: PublicKeyCreationOptions): PublicKeyCredentialCreationOptions {
    return {
      challenge: this.base64urlToUint8Array(safe.challenge),
      rp: safe.rp,
      user: {
        id: this.base64urlToUint8Array(safe.user.id),
        name: safe.user.name,
        displayName: safe.user.displayName,
      },
      pubKeyCredParams: safe.pubKeyCredParams,
      authenticatorSelection: safe.authenticatorSelection,
      timeout: safe.timeout,
      attestation: safe.attestation,
      extensions: safe.extensions,
      excludeCredentials: safe.excludeCredentials?.map((cred) => ({
        id: this.base64urlToUint8Array(cred.id),
        type: 'public-key' as const,
        transports: cred.transports,
      })),
    };
  }

  /**
   * Decodes base64url string to binary Uint8Array
   * Handles proper padding and character replacement for base64url format
   * @param base64url - Base64url encoded string (no padding, using - and _)
   * @returns Decoded binary data as Uint8Array
   */
  base64urlToUint8Array(base64url: string): Uint8Array {
    const base64 = base64url
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(Math.ceil(base64url.length / 4) * 4, '=');
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  /**
   * Encodes binary data to base64url string format
   * Safely handles large arrays without stack overflow
   * @param bytes - Binary data to encode
   * @returns Base64url encoded string (no padding, using - and _)
   */
  toBase64url(bytes: Uint8Array): string {
    // Fix: Avoid using spread operator with large arrays to prevent stack overflow
    let binary = '';
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  }

  /**
   * Converts plugin format to WebAuthn API format for authentication
   * Transforms base64url encoded strings to Uint8Arrays
   * @param crossPlatform - Authentication options with base64url encoded fields
   * @returns Native WebAuthn request options with Uint8Array fields
   */
  toPublicKeyCredentialRequestOptions(
    crossPlatform: PublicKeyAuthenticationOptions,
  ): PublicKeyCredentialRequestOptions {
    return {
      challenge: this.base64urlToUint8Array(crossPlatform.challenge),
      allowCredentials: crossPlatform.allowCredentials?.map((cred) => ({
        id: this.base64urlToUint8Array(cred.id),
        type: 'public-key',
        transports: cred.transports,
      })),
      rpId: crossPlatform.rpId,
      timeout: crossPlatform.timeout,
      userVerification: crossPlatform.userVerification,
      extensions: crossPlatform.extensions,
    };
  }
}
