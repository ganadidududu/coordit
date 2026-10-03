package com.inseong.coordit.data

import androidx.test.platform.app.InstrumentationRegistry
import com.inseong.coordit.data.local.SecureSessionStore
import com.inseong.coordit.data.model.AuthSession
import com.inseong.coordit.data.model.AuthUser
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class SecureSessionStoreTest {
    private fun isolatedContext(): android.content.Context {
        val app = InstrumentationRegistry.getInstrumentation().targetContext
        return object : android.content.ContextWrapper(app) {
            override fun getNoBackupFilesDir(): File = File(app.cacheDir, "secure-session-tests").apply { mkdirs() }
            override fun getPackageName(): String = app.packageName + ".secure-session-tests"
        }
    }

    @Test fun encryptedSessionSurvivesNewStoreAndClears() = runBlocking {
        val context = isolatedContext()
        val session = AuthSession("secret-access-test", "secret-refresh-test", AuthUser("test", "test@example.com"))
        val store = SecureSessionStore(context)
        try {
            store.write(session)
            val bytes = File(context.noBackupFilesDir, "auth-session.enc").readBytes().toString(Charsets.ISO_8859_1)
            assertFalse(bytes.contains(session.accessToken))
            assertFalse(bytes.contains(session.refreshToken))
            assertEquals(session, SecureSessionStore(context).read())
            store.clear()
            assertNull(store.read())
        } finally { store.clear() }
    }
    @Test fun atomicBackupIsRecoveredWhenBaseFileIsAbsent() = runBlocking {
        val context = isolatedContext()
        val store = SecureSessionStore(context)
        val session = AuthSession("backup-access", "backup-refresh", AuthUser("test", ""))
        val file = File(context.noBackupFilesDir, "auth-session.enc")
        val backup = File(file.path + ".bak")
        try {
            store.write(session)
            assertTrue(file.renameTo(backup))
            assertEquals(session, SecureSessionStore(context).read())
        } finally { store.clear(); backup.delete() }
    }

    @Test fun decryptedMalformedUserIsRejected() = runBlocking {
        val context = isolatedContext()
        val store = SecureSessionStore(context)
        try {
            store.write(AuthSession("a", "r", AuthUser("u", "")))
            val keys = java.security.KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val key = keys.getKey("${context.packageName}.auth-session.v1", null) as javax.crypto.SecretKey
            val malformedPayloads = listOf(
                """{"accessToken":"a","refreshToken":"r","user":null}""",
                """{"accessToken":"a","refreshToken":"r","user":{"id":"u"}}""",
                """{"accessToken":"a","refreshToken":"r","user":{"id":"","email":""}}""",
            )
            for (payload in malformedPayloads) {
                val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, key)
                val encrypted = cipher.doFinal(payload.toByteArray(Charsets.UTF_8))
                val bytes = byteArrayOf(1) + cipher.iv + encrypted
                File(context.noBackupFilesDir, "auth-session.enc").writeBytes(bytes)
                try { store.read(); fail("Malformed encrypted session must be rejected") }
                catch (_: com.google.gson.JsonParseException) { }
            }
        } finally { store.clear() }
    }

}
