package com.inseong.coordit.closet

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.inseong.coordit.data.closet.ClosetOcr
import com.inseong.coordit.data.closet.OcrCell
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class ClosetOcrDeviceTest {
    @Test
    fun bundledKoreanRecognizerReadsSizeChartIntoProductionParser() {
        val bitmap = sizeChartBitmap()
        val recognizer = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
        try {
            val recognition = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 45, TimeUnit.SECONDS)
            val cells = recognition.textBlocks.flatMap { it.lines }.flatMap { line ->
                line.elements.mapNotNull { element ->
                    element.boundingBox?.let { box ->
                        OcrCell(element.text, box.left.toFloat(), box.top.toFloat(), box.width().toFloat(), box.height().toFloat())
                    }
                }
            }
            val rows = ClosetOcr.parse(cells, upper = true)
            val evidence = "Recognized text: ${recognition.text}; parsed rows: $rows"
            assertEquals(evidence, listOf("M", "L"), rows.map { it.label })
            assertEquals(evidence, mapOf("shoulder_width" to 42.0, "chest_width" to 50.0, "total_length" to 66.0, "sleeve_length" to 23.0), rows[0].measurements)
            assertEquals(evidence, mapOf("shoulder_width" to 44.0, "chest_width" to 52.0, "total_length" to 68.0, "sleeve_length" to 25.0), rows[1].measurements)
        } finally {
            recognizer.close()
            bitmap.recycle()
        }
    }

    private fun sizeChartBitmap(): Bitmap {
        val bitmap = Bitmap.createBitmap(1700, 550, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            textSize = 48f
        }
        val centers = listOf(140f, 480f, 830f, 1170f, 1510f)
        val rows = listOf(
            listOf("SIZE", "SHOULDER", "CHEST", "LENGTH", "SLEEVE"),
            listOf("M", "42", "50", "66", "23"),
            listOf("L", "44", "52", "68", "25"),
        )
        rows.forEachIndexed { rowIndex, row ->
            row.forEachIndexed { columnIndex, text ->
                canvas.drawText(text, centers[columnIndex], 110f + rowIndex * 165f, paint)
            }
        }
        return bitmap
    }
}
