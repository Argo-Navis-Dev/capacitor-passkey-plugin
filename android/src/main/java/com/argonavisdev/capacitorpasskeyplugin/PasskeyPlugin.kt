package com.argonavisdev.capacitorpasskeyplugin

import android.app.Activity
import android.util.Log
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialInterruptedException
import androidx.credentials.exceptions.CreateCredentialProviderConfigurationException
import androidx.credentials.exceptions.CreateCredentialUnknownException
import androidx.credentials.exceptions.CreateCredentialUnsupportedException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialInterruptedException
import androidx.credentials.exceptions.GetCredentialProviderConfigurationException
import androidx.credentials.exceptions.GetCredentialUnknownException
import androidx.credentials.exceptions.GetCredentialUnsupportedException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.publickeycredential.CreatePublicKeyCredentialDomException
import androidx.credentials.exceptions.publickeycredential.GetPublicKeyCredentialDomException
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.TimeoutCancellationException
import org.json.JSONObject
import android.util.Base64

/**
 * Android implementation of the PasskeyPlugin using Credential Manager API
 * Provides passkey creation and authentication for Android devices
 * Handles timeout enforcement, input validation, and standardized error codes
 * Minimum API Level: 28 (Android 9.0)
 */
@CapacitorPlugin(name = "PasskeyPlugin")
class PasskeyPlugin : Plugin() {

    private var mainScope: CoroutineScope? = null

    /**
     * Initializes the plugin when loaded by Capacitor
     * Sets up coroutine scope for async operations
     */
    override fun load() {
        super.load()
        // Initialize scope when plugin loads
        mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    }

    /**
     * Cleanup when plugin is destroyed
     * Cancels coroutine scope to prevent memory leaks
     */
    override fun handleOnDestroy() {
        // Cancel scope to prevent memory leaks
        mainScope?.cancel()
        mainScope = null
        super.handleOnDestroy()
    }

    object ErrorCodes {
        const val UNKNOWN = "UNKNOWN_ERROR"
        const val CANCELLED = "CANCELLED"
        const val DOM = "DOM_ERROR"
        const val NO_ACTIVITY = "NO_ACTIVITY"
        const val UNSUPPORTED = "UNSUPPORTED_ERROR"
        const val PROVIDER_CONFIG_ERROR = "PROVIDER_CONFIG_ERROR"
        const val INTERRUPTED = "INTERRUPTED"
        const val NO_CREDENTIAL = "NO_CREDENTIAL"
        const val TIMEOUT = "TIMEOUT"
        const val INVALID_INPUT = "INVALID_INPUT"
    }

    /**
     * Creates a new passkey credential for the user
     * Validates input, enforces timeout, and handles platform-specific credential creation
     * @param call PluginCall containing publicKey parameters following WebAuthn spec
     * @return Resolves with credential creation result or rejects with error code
     */
    @PluginMethod
    fun createPasskey(call: PluginCall) {
        // Security: Don't log sensitive data
        val rpId = call.getObject("publicKey")
            ?.optJSONObject("rp")
            ?.optString("id")
            ?.takeIf { it.isNotBlank() }
            ?: "unknown"

        Log.d("PasskeyPlugin", "CreatePasskey called for rpId: $rpId")
        val publicKey = call.getObject("publicKey")

        if (publicKey == null) {
            Log.e("PasskeyPlugin", "Passkey registration failed, publicKey is null in request!")
            handlePluginError(call, code = ErrorCodes.INVALID_INPUT, message = "PublicKey is null in request!")
            return
        }

        // Input validation
        val challenge = publicKey.optString("challenge")
        if (challenge.isNullOrEmpty() || !isValidBase64Url(challenge)) {
            handlePluginError(call, code = ErrorCodes.INVALID_INPUT, message = "Invalid or missing challenge")
            return
        }

        val userObj = publicKey.optJSONObject("user")
        val userId = userObj?.optString("id")
        if (userId.isNullOrEmpty() || !isValidBase64Url(userId)) {
            handlePluginError(call, code = ErrorCodes.INVALID_INPUT, message = "Invalid or missing user.id")
            return
        }

        // Parse and validate authenticatorAttachment
        val authenticatorSelection = publicKey.optJSONObject("authenticatorSelection")
        val authenticatorAttachment = authenticatorSelection?.optString("authenticatorAttachment")

        // Validate authenticatorAttachment value if present
        if (authenticatorAttachment != null && authenticatorAttachment.isNotEmpty() &&
            authenticatorAttachment != "platform" &&
            authenticatorAttachment != "cross-platform") {
            handlePluginError(
                call,
                code = ErrorCodes.INVALID_INPUT,
                message = "Invalid authenticatorAttachment: must be 'platform' or 'cross-platform', got '$authenticatorAttachment'"
            )
            return
        }

        // Log for debugging
        Log.d("PasskeyPlugin", "Authenticator attachment type: ${authenticatorAttachment ?: "not specified"}")

        // For security keys, verify transports are included
        if (authenticatorAttachment == "cross-platform") {
            val excludeCreds = publicKey.optJSONArray("excludeCredentials")
            if (excludeCreds != null) {
                for (i in 0 until excludeCreds.length()) {
                    val cred = excludeCreds.optJSONObject(i)
                    if (cred?.has("transports") != true) {
                        Log.w("PasskeyPlugin", "Security key credential missing transports hint at index $i")
                    }
                }
            }
        }

        val credentialManager = CredentialManager.create(context)
        val publicKeyJson = publicKey.toString()

        // For cross-platform authenticators, set preferImmediately to false
        // This hints to the system that we're willing to wait for external devices
        val preferImmediately = authenticatorAttachment != "cross-platform"

        val createPublicKeyCredentialRequest =
            CreatePublicKeyCredentialRequest(
                requestJson = publicKeyJson,
                preferImmediatelyAvailableCredentials = preferImmediately
            )

        // Get timeout from options, default to 60 seconds
        val timeout = publicKey.optLong("timeout", 60000L)

        val scope = mainScope ?: run {
            handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "Plugin not initialized")
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                withTimeout(timeout) {
                val activity: Activity? = activity
                if (activity == null) {
                    handlePluginError(call, code = ErrorCodes.NO_ACTIVITY, message = "No activity found to handle passkey registration!")
                    return@withTimeout
                }
                val credentialResult = activity.let {
                    credentialManager.createCredential(
                        it,
                        createPublicKeyCredentialRequest
                    )
                }
                val registrationResponseStr =
                    credentialResult.data.getString("androidx.credentials.BUNDLE_KEY_REGISTRATION_RESPONSE_JSON")
                // Security: Don't log full response with sensitive data
                Log.d("PasskeyPlugin", "Passkey registration completed successfully")
                if (!registrationResponseStr.isNullOrEmpty()) {
                    //Convert the response data to a JSONObject
                    val registrationResponseJson = JSONObject(registrationResponseStr)

                    val responseField = registrationResponseJson.optJSONObject("response")
                    if (responseField == null) {
                        handlePluginError(call, message = "Malformed response: missing 'response' field")
                        return@withTimeout
                    }
                    val passkeyResponse = JSObject().apply {
                        put("id", registrationResponseJson.optString("id"))
                        put("rawId", registrationResponseJson.optString("rawId")) // base64url string
                        put("type", registrationResponseJson.optString("type"))
                        put("response", JSObject().apply {
                            put("attestationObject", responseField.optString("attestationObject"))
                            put("clientDataJSON", responseField.optString("clientDataJSON"))
                        })
                    }

                    call.resolve(passkeyResponse)

                } else {
                    handlePluginError(call, message = "No response data received from passkey registration!")
                }
                } // End of withTimeout
            } catch (e: TimeoutCancellationException) {
                handlePluginError(call, code = ErrorCodes.TIMEOUT, message = "Operation timed out after ${timeout}ms")
            } catch (e: CreateCredentialException) {
                handleCreatePasskeyException(call, e, authenticatorAttachment)
            } catch (e: Exception) {
                Log.e("PasskeyPlugin", "Unexpected error during passkey creation: ${e.message}", e)
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unexpected error occurred during passkey creation: ${e.message ?: "Unknown error"}")
            }
        }
    }

    /**
     * Maps credential creation exceptions to standardized error codes
     * Provides consistent error handling across different exception types
     * @param call PluginCall to reject with appropriate error
     * @param e CreateCredentialException thrown during passkey creation
     * @param authenticatorAttachment Authenticator type requested (for enhanced error messages)
     */
    private fun handleCreatePasskeyException(call: PluginCall, e: CreateCredentialException, authenticatorAttachment: String? = null) {
        Log.e("PasskeyPlugin", "Error during passkey creation: ${e.message}", e)
        when (e) {
            is CreatePublicKeyCredentialDomException -> {
                // Log full exception details for debugging
                Log.e("PasskeyPlugin", "DOM Exception - type: ${e.type}, errorMessage: ${e.errorMessage}, message: ${e.message}")

                // Check for specific CTAP/FIDO errors
                val errorMsg = e.errorMessage?.toString() ?: e.message ?: ""

                // Provide helpful context for common low-level errors
                val enhancedMsg = when {
                    errorMsg.contains("0x6f00") || errorMsg.contains("Low level error 0x6f00") -> {
                        "NFC communication failed (0x6f00). Hold security key steady near NFC antenna for 2-3 seconds."
                    }
                    e.type.contains("UNKNOWN_ERROR") -> {
                        "Unknown error from Android Credential Manager. Check Digital Asset Links configuration for rpId."
                    }
                    else -> errorMsg.ifEmpty { "DOM error: ${e.type}" }
                }

                Log.e("PasskeyPlugin", "Final error message: $enhancedMsg")
                handlePluginError(call, code = ErrorCodes.DOM, message = enhancedMsg)
                return
            }
            is CreateCredentialCancellationException -> {
                handlePluginError(call, code = ErrorCodes.CANCELLED, message = "Passkey creation was cancelled by the user.")
                return
            }
            is CreateCredentialInterruptedException -> {
                handlePluginError(call, code = ErrorCodes.INTERRUPTED, message = "Passkey creation was interrupted.")
                return
            }
            is CreateCredentialProviderConfigurationException -> {
                handlePluginError(call, code = ErrorCodes.PROVIDER_CONFIG_ERROR, message = "Provider configuration error: ${e.errorMessage ?: "Unknown error"}")
                return
            }
            is CreateCredentialUnknownException -> {
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unknown error occurred during passkey creation: ${e.errorMessage ?: "Unknown error"}")
                return
            }
            is CreateCredentialUnsupportedException -> {
                // Enhanced error message for cross-platform authenticators
                val msg = if (authenticatorAttachment == "cross-platform") {
                    "External security keys (YubiKey) not supported on this device. Ensure NFC is enabled and the key supports FIDO2/WebAuthn."
                } else {
                    "Passkey creation is not supported on this device or platform."
                }
                handlePluginError(call, code = ErrorCodes.UNSUPPORTED, message = msg)
                return
            }
            else -> {
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unknown error occurred during passkey creation: ${e.message ?: "Unknown error"}")
            }
        }
    }


    /**
     * Authenticates user with an existing passkey
     * Validates challenge, enforces timeout, and retrieves credential assertion
     * @param call PluginCall containing publicKey authentication parameters
     * @return Resolves with authentication assertion or rejects with error code
     */
    @PluginMethod
    fun authenticate(call: PluginCall) {
        val publicKey = call.getObject("publicKey")

        if (publicKey == null) {
            handlePluginError(call, code = ErrorCodes.INVALID_INPUT, message = "PublicKey is null in request!")
            return
        }

        // Input validation
        val challenge = publicKey.optString("challenge")
        if (challenge.isNullOrEmpty() || !isValidBase64Url(challenge)) {
            handlePluginError(call, code = ErrorCodes.INVALID_INPUT, message = "Invalid or missing challenge")
            return
        }

        // Parse and validate authenticatorAttachment
        val authenticatorAttachment = publicKey.optString("authenticatorAttachment")

        // Validate authenticatorAttachment value if present
        if (authenticatorAttachment != null && authenticatorAttachment.isNotEmpty() &&
            authenticatorAttachment != "platform" &&
            authenticatorAttachment != "cross-platform") {
            handlePluginError(
                call,
                code = ErrorCodes.INVALID_INPUT,
                message = "Invalid authenticatorAttachment: must be 'platform' or 'cross-platform', got '$authenticatorAttachment'"
            )
            return
        }

        Log.d("PasskeyPlugin", "Authenticate with attachment type: ${authenticatorAttachment.ifEmpty { "not specified" }}")

        // For security keys, verify credentials include transport hints
        if (authenticatorAttachment == "cross-platform") {
            val allowCreds = publicKey.optJSONArray("allowCredentials")
            if (allowCreds == null || allowCreds.length() == 0) {
                Log.w("PasskeyPlugin", "Cross-platform auth without allowCredentials may prompt for new key creation")
            } else {
                for (i in 0 until allowCreds.length()) {
                    val cred = allowCreds.optJSONObject(i)
                    val transports = cred?.optJSONArray("transports")
                    if (transports == null || transports.length() == 0) {
                        Log.w("PasskeyPlugin", "Security key credential at index $i missing transports - may fail to detect key")
                    }
                }
            }
        }

        val publicKeyString = publicKey.toString()

        val credentialManager = CredentialManager.create(context)

        // Only prefer immediately available for platform authenticators
        // Security keys require user interaction (tap/insert)
        val preferImmediate = authenticatorAttachment != "cross-platform"

        val getCredentialRequest =
            GetCredentialRequest(
                listOf(
                    GetPublicKeyCredentialOption(
                        publicKeyString
                    )
                ), preferImmediatelyAvailableCredentials = preferImmediate
            )

        // Get timeout from options, default to 60 seconds
        val timeout = publicKey.optLong("timeout", 60000L)

        val scope = mainScope ?: run {
            handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "Plugin not initialized")
            return
        }
        scope.launch(Dispatchers.IO) {
            try {
                withTimeout(timeout) {
                val activity: Activity? = activity
                if (activity == null) {
                    handlePluginError(call, code = ErrorCodes.NO_ACTIVITY, message = "No activity found to handle passkey authentication!")
                    return@withTimeout
                }
                val credentialResult =
                    activity.let { credentialManager.getCredential(it, getCredentialRequest) }

                val authResponseStr =
                    credentialResult.credential.data.getString("androidx.credentials.BUNDLE_KEY_AUTHENTICATION_RESPONSE_JSON")
                if (authResponseStr == null) {
                    handlePluginError(call, message = "No response from credential manager.")
                    return@withTimeout
                }
                val authResponseJson = JSONObject(authResponseStr)
                val responseField = authResponseJson.optJSONObject("response")
                if (responseField == null) {
                    handlePluginError(call, message = "Malformed response: missing 'response' field")
                    return@withTimeout
                }
                val passkeyResponse = JSObject().apply {
                    put("id", authResponseJson.optString("id"))
                    put("rawId", authResponseJson.optString("rawId"))
                    put("type", authResponseJson.optString("type"))
                    put("response", JSObject().apply {
                        put("clientDataJSON", responseField.optString("clientDataJSON"))
                        put("authenticatorData", responseField.optString("authenticatorData"))
                        put("signature", responseField.optString("signature"))
                        put("userHandle", responseField.optString("userHandle", null))
                    })
                }

                call.resolve(passkeyResponse)
                } // End of withTimeout
            } catch (e: TimeoutCancellationException) {
                handlePluginError(call, code = ErrorCodes.TIMEOUT, message = "Operation timed out after ${timeout}ms")
            } catch (e: GetCredentialException) {
                handleAuthenticationError(call, e, authenticatorAttachment)
            } catch (e: Exception) {
                Log.e("PasskeyPlugin", "Unexpected error during passkey authentication: ${e.message}", e)
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unexpected error occurred during passkey authentication: ${e.message ?: "Unknown error"}")
            }
        }
    }

    /**
     * Maps credential retrieval exceptions to standardized error codes
     * Handles various authentication failure scenarios consistently
     * @param call PluginCall to reject with appropriate error
     * @param e GetCredentialException thrown during authentication
     * @param authenticatorAttachment Authenticator type requested (for enhanced error messages)
     */
    private fun handleAuthenticationError(call: PluginCall, e: GetCredentialException, authenticatorAttachment: String? = null) {
        Log.e("PasskeyPlugin", "Error during passkey authentication: ${e.message}", e)
        when (e) {
            is GetPublicKeyCredentialDomException -> {
                // Log full exception details for debugging
                Log.e("PasskeyPlugin", "DOM Exception - type: ${e.type}, errorMessage: ${e.errorMessage}, message: ${e.message}")

                // Extract more details from the exception type
                val domErrorType = when {
                    e.type.contains("UNKNOWN_ERROR") -> "Unknown error from Android Credential Manager. This often indicates: 1) Digital Asset Links misconfiguration for rpId, 2) Missing or invalid assetlinks.json, 3) Package name mismatch, or 4) Device compatibility issue with the authenticator type."
                    else -> e.type
                }

                val errorMsg = e.errorMessage?.toString()
                    ?: e.message
                    ?: "DOM error: $domErrorType"

                Log.e("PasskeyPlugin", "Final error message: $errorMsg")
                handlePluginError(call, code = ErrorCodes.DOM, message = errorMsg)
                return
            }
            is GetCredentialCancellationException -> {
                handlePluginError(call, code = ErrorCodes.CANCELLED, message = "Passkey authentication was cancelled by the user.")
                return
            }
            is GetCredentialInterruptedException -> {
                handlePluginError(call, code = ErrorCodes.INTERRUPTED, message = "Passkey authentication was interrupted.")
                return
            }
            is GetCredentialProviderConfigurationException -> {
                handlePluginError(call, code = ErrorCodes.PROVIDER_CONFIG_ERROR, message = "Provider configuration error: ${e.errorMessage ?: "Unknown error"}")
                return
            }
            is GetCredentialUnknownException -> {
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unknown error occurred during passkey authentication: ${e.errorMessage ?: "Unknown error"}")
                return
            }
            is GetCredentialUnsupportedException -> {
                // Enhanced error message for cross-platform authenticators
                val msg = if (authenticatorAttachment == "cross-platform") {
                    "External security keys (YubiKey) not supported on this device. Ensure NFC is enabled and the key supports FIDO2/WebAuthn."
                } else {
                    "Passkey authentication is not supported on this device or platform."
                }
                handlePluginError(call, code = ErrorCodes.UNSUPPORTED, message = msg)
                return
            }
            is NoCredentialException -> {
                handlePluginError(call, code = ErrorCodes.NO_CREDENTIAL, message = "No passkey found for the given request.")
                return
            }
            else -> {
                handlePluginError(call, code = ErrorCodes.UNKNOWN, message = "An unknown error occurred during passkey authentication: ${e.message ?: "Unknown error"}")
            }
        }
    }

    /**
     * Centralized error handler for plugin operations
     * Logs error and rejects call with structured error data
     * @param call PluginCall to reject
     * @param code Error code matching Web implementation codes
     * @param message Human-readable error description
     */
    fun handlePluginError(call: PluginCall, code: String = ErrorCodes.UNKNOWN, message: String) {
        Log.e("PasskeyPlugin", "Error: $message")
        val errorData = JSObject().apply {
            put("code", code)
            put("message", message)
        }
        call.reject(message, code, errorData)
    }

    /**
     * Validates base64url encoded strings
     * Checks format and attempts decoding to ensure validity
     * @param input String to validate as base64url
     * @return true if valid base64url format, false otherwise
     */
    private fun isValidBase64Url(input: String): Boolean {
        return try {
            // Base64url uses - and _ instead of + and /
            val base64UrlRegex = Regex("^[A-Za-z0-9_-]+$")
            if (!base64UrlRegex.matches(input)) {
                return false
            }
            // Try to decode to verify it's valid
            val paddedInput = when (input.length % 4) {
                2 -> input + "=="
                3 -> input + "="
                else -> input
            }
            Base64.decode(paddedInput.replace('-', '+').replace('_', '/'), Base64.DEFAULT)
            true
        } catch (e: Exception) {
            false
        }
    }
}