package com.gadgeon.generic_flutter_app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Notices when the phone's fingerprints / faces change after biometric login was turned on.
 *
 * "remember" creates a Keystore key that Android itself destroys when a biometric is added or all
 * are removed (setInvalidatedByBiometricEnrollment). "changed" only opens a cipher with that key:
 * nothing is encrypted and no prompt is shown. Holds no secrets and logs nothing.
 */
object BiometricEnrollment : MethodChannel.MethodCallHandler {
    const val CHANNEL = "app/biometric_enrollment"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "biometric_enrollment_v1"

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "remember" -> result.success(remember())
            "changed" -> result.success(changed())
            "forget" -> {
                forget()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** False when no key can be made, e.g. no strong (class 3) biometric is enrolled. */
    private fun remember(): Boolean = try {
        forget()
        val spec = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
            init(spec)
            generateKey()
        }
        true
    } catch (e: Exception) {
        false
    }

    /** True when the key is gone or Android has invalidated it. */
    private fun changed(): Boolean = try {
        val key = keyStore().getKey(ALIAS, null) as? SecretKey
        if (key == null) {
            true
        } else {
            Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.ENCRYPT_MODE, key)
            false
        }
    } catch (e: KeyPermanentlyInvalidatedException) {
        true
    } catch (e: Exception) {
        // Cannot tell: treat as changed, so a password is needed.
        true
    }

    private fun forget() {
        try {
            keyStore().deleteEntry(ALIAS)
        } catch (e: Exception) {
            // Nothing to delete.
        }
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
}
