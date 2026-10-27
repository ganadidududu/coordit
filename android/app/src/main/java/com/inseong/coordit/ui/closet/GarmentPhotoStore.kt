package com.inseong.coordit.ui.closet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.AtomicFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.security.MessageDigest

class GarmentPhotoStore(context: Context, userId: String) {
    private val root = File(context.noBackupFilesDir, "garment-photos/${digest(userId)}")

    suspend fun load(itemId: String): Bitmap? = withContext(Dispatchers.IO) {
        val file = AtomicFile(File(root, "${digest(itemId)}.jpg"))
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return@withContext null
        try { file.openRead().use { BitmapFactory.decodeStream(it) } } catch (_: IOException) { null }
    }

    suspend fun save(itemId: String, bitmap: Bitmap) = withContext(Dispatchers.IO) {
        if (!root.isDirectory && !root.mkdirs()) throw IOException("Could not create garment photo directory")
        val file = AtomicFile(File(root, "${digest(itemId)}.jpg"))
        val output = file.startWrite()
        try {
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, output)) throw IOException("Could not encode garment photo")
            file.finishWrite(output)
        } catch (error: Exception) { file.failWrite(output); throw error }
    }

    private fun digest(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
}
