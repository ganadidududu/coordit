package com.inseong.coordit.auth

import android.app.Activity
import android.content.Context
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.inseong.coordit.BuildConfig
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

class SignInUnavailable(message: String) : Exception(message)

class GoogleCredential(val idToken: String, val rawNonce: String) {
    override fun toString() = "GoogleCredential(redacted)"
}

object GoogleNonce {
    fun create(): String = Base64.getUrlEncoder().withoutPadding().encodeToString(
        ByteArray(32).also { SecureRandom().nextBytes(it) },
    )
    fun requestHash(raw: String): String = MessageDigest.getInstance("SHA-256")
        .digest(raw.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
}

class GoogleIdentity(context: Context) {
    private val manager = CredentialManager.create(context.applicationContext)
    suspend fun signIn(activity: Activity): GoogleCredential? {
        val clientId = BuildConfig.GOOGLE_WEB_CLIENT_ID.trim()
        if (clientId.isEmpty()) throw SignInUnavailable("Google 로그인을 아직 사용할 수 없어요. 잠시 후 다시 시도해 주세요.")
        val rawNonce = GoogleNonce.create()
        val option = GetSignInWithGoogleOption.Builder(clientId)
            .setNonce(GoogleNonce.requestHash(rawNonce)).build()
        val result = try {
            manager.getCredential(activity, GetCredentialRequest.Builder().addCredentialOption(option).build())
        } catch (_: GetCredentialCancellationException) {
            return null
        } catch (_: NoCredentialException) {
            throw SignInUnavailable("Google 계정을 선택할 수 없어요. 기기의 Google 계정을 확인해 주세요.")
        }
        val credential = result.credential
        if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw SignInUnavailable("Google 로그인 정보를 확인하지 못했어요. 다시 시도해 주세요.")
        }
        val token = GoogleIdTokenCredential.createFrom(credential.data).idToken
        if (token.isBlank()) throw SignInUnavailable("Google 로그인 정보를 확인하지 못했어요. 다시 시도해 주세요.")
        return GoogleCredential(token, rawNonce)
    }
    suspend fun clear() { manager.clearCredentialState(ClearCredentialStateRequest()) }
}
