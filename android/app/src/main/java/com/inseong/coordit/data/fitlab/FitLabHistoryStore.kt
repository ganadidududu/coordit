package com.inseong.coordit.data.fitlab

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

data class FitLabHistorySnapshot(
    val schemaVersion: Int = 1,
    val analysisId: String,
    val userId: String,
    val savedAt: Long,
    val productName: String,
    val category: String,
    val upper: Boolean,
    val source: FitLabSource,
    val referenceCount: Int = 0,
    val recommendation: FitLabRecommendation,
    val report: FitLabReportResponse,
)

interface FitLabHistoryStorage {
    suspend fun load(userId: String): List<FitLabHistorySnapshot>
    suspend fun save(snapshot: FitLabHistorySnapshot): List<FitLabHistorySnapshot>
    suspend fun delete(userId: String, analysisId: String): List<FitLabHistorySnapshot>
}

class FitLabHistoryStore(context: Context, private val gson: Gson) : FitLabHistoryStorage {
    private val root = File(context.noBackupFilesDir, "fitlab-history")
    private val type = object : TypeToken<List<FitLabHistorySnapshot>>() {}.type

    override suspend fun load(userId: String): List<FitLabHistorySnapshot> = withContext(Dispatchers.IO) {
        require(userId.isNotBlank()) { "사용자 정보를 확인할 수 없어요." }
        synchronized(this@FitLabHistoryStore) { read(userId) }
    }

    override suspend fun save(snapshot: FitLabHistorySnapshot): List<FitLabHistorySnapshot> = withContext(Dispatchers.IO) {
        require(snapshot.userId.isNotBlank() && snapshot.analysisId.isNotBlank()) { "저장할 분석 정보를 확인할 수 없어요." }
        synchronized(this@FitLabHistoryStore) {
            val values = (listOf(snapshot) + read(snapshot.userId).filterNot { it.analysisId == snapshot.analysisId })
                .sortedByDescending { it.savedAt }.take(50)
            write(snapshot.userId, values)
            values
        }
    }

    override suspend fun delete(userId: String, analysisId: String): List<FitLabHistorySnapshot> = withContext(Dispatchers.IO) {
        synchronized(this@FitLabHistoryStore) {
            val values = read(userId).filterNot { it.analysisId == analysisId }
            write(userId, values)
            values
        }
    }

    private fun read(userId: String): List<FitLabHistorySnapshot> {
        val file = file(userId)
        if (!file.exists()) return emptyList()
        val parsed = runCatching { gson.fromJson<List<FitLabHistorySnapshot>>(file.readText(), type) }
            .getOrElse {
                quarantine(file)
                return emptyList()
            }
        if (parsed == null) {
            quarantine(file)
            return emptyList()
        }
        return parsed.filter { it.schemaVersion == 1 && it.userId == userId }
            .distinctBy { it.analysisId }.sortedByDescending { it.savedAt }.take(50)
    }

    private fun quarantine(file: File) {
        val destination = File(file.parentFile, "${file.nameWithoutExtension}.corrupt-${System.currentTimeMillis()}.json")
        runCatching { Files.move(file.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING) }
    }

    private fun write(userId: String, values: List<FitLabHistorySnapshot>) {
        root.mkdirs()
        val destination = file(userId)
        val temporary = File.createTempFile("history-", ".tmp", root)
        try {
            FileOutputStream(temporary).use { output ->
                output.write(gson.toJson(values, type).toByteArray(Charsets.UTF_8))
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
    }

    private fun file(userId: String): File {
        val digest = MessageDigest.getInstance("SHA-256").digest(userId.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
        return File(root, "$digest.json")
    }
}
