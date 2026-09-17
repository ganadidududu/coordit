package com.inseong.coordit.data.fitlab

import android.content.Context
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

data class FitLabPendingSubmission(
    val userId: String,
    val draft: FitLabDraft,
    val checkpoint: FitLabCheckpoint,
    val recommendation: FitLabRecommendation? = null,
    val schemaVersion: Int = 1,
)

interface FitLabSubmissionStorage {
    suspend fun load(userId: String): FitLabPendingSubmission?
    suspend fun save(value: FitLabPendingSubmission)
    suspend fun clear(userId: String)
}

class FitLabSubmissionStore(context: Context, private val gson: Gson) : FitLabSubmissionStorage {
    private val root = File(context.noBackupFilesDir, "fitlab-pending")

    override suspend fun load(userId: String): FitLabPendingSubmission? = withContext(Dispatchers.IO) {
        require(userId.isNotBlank())
        synchronized(this@FitLabSubmissionStore) {
            val source = file(userId)
            if (!source.exists()) return@synchronized null
            runCatching { gson.fromJson(source.readText(), FitLabPendingSubmission::class.java) }
                .getOrNull()
                ?.takeIf { it.schemaVersion == 1 && it.userId == userId }
        }
    }

    override suspend fun save(value: FitLabPendingSubmission): Unit = withContext(Dispatchers.IO) {
        require(value.userId.isNotBlank())
        synchronized(this@FitLabSubmissionStore) {
            root.mkdirs()
            val destination = file(value.userId)
            val temporary = File.createTempFile("submission-", ".tmp", root)
            try {
                FileOutputStream(temporary).use { output ->
                    output.write(gson.toJson(value).toByteArray(Charsets.UTF_8))
                    output.fd.sync()
                }
                try {
                    Files.move(temporary.toPath(), destination.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
                } catch (_: AtomicMoveNotSupportedException) {
                    Files.move(temporary.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING)
                }
            } finally {
                if (temporary.exists()) temporary.delete()
            }
            Unit
        }
    }

    override suspend fun clear(userId: String): Unit = withContext(Dispatchers.IO) {
        synchronized(this@FitLabSubmissionStore) { file(userId).delete(); Unit }
    }

    private fun file(userId: String): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(userId.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return File(root, "$digest.json")
    }
}
