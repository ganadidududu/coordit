package com.inseong.coordit.data.local

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import com.inseong.coordit.data.model.CoorditJson
import com.inseong.coordit.data.model.AuthSession
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

class SecureSessionStore(context: Context) : SessionStore {
    private val file = AtomicFile(File(context.noBackupFilesDir, "auth-session.enc"))
    private val keyAlias = "${context.packageName}.auth-session.v1"
    private val mutex = Mutex()
    private val gson = CoorditJson.create()

    override suspend fun read(): AuthSession? = withContext(Dispatchers.IO) {
        mutex.withLock {
            val bytes = try { file.readFully() } catch (_: FileNotFoundException) { return@withLock null }
            if (bytes.size < 30 || bytes[0].toInt() != 1) throw IOException("Invalid encrypted session")
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(1, 13)))
            val decoded = cipher.doFinal(bytes.copyOfRange(13, bytes.size)).toString(Charsets.UTF_8)
            val session = gson.fromJson(decoded, AuthSession::class.java)
            if (session == null || !session.isValid()) throw IOException("Invalid saved session")
            session
        }
    }

    override suspend fun write(session: AuthSession) = withContext(Dispatchers.IO) {
        require(session.isValid()) { "Invalid session" }
        mutex.withLock {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key())
            val encrypted = cipher.doFinal(gson.toJson(session).toByteArray(Charsets.UTF_8))
            val bytes = ByteBuffer.allocate(1 + cipher.iv.size + encrypted.size).put(1.toByte()).put(cipher.iv).put(encrypted).array()
            val stream = file.startWrite()
            try {
                stream.write(bytes)
                file.finishWrite(stream)
            } catch (error: Exception) {
                file.failWrite(stream)
                throw error
            }
        }
    }

    override suspend fun clear() = withContext(Dispatchers.IO) { mutex.withLock { file.delete() } }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build())
        }.generateKey()
    }
}
