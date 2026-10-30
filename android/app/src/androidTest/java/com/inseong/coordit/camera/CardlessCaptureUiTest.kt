package com.inseong.coordit.camera

import android.graphics.Bitmap
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import com.google.ar.core.Pose
import com.inseong.coordit.data.fitlab.camera.FrozenGarmentPlane
import com.inseong.coordit.preview.AccountPreviewActivity
import com.inseong.coordit.ui.fitlab.camera.CardlessGarmentCapture
import com.inseong.coordit.ui.fitlab.camera.CardlessGarmentResult
import com.inseong.coordit.ui.fitlab.camera.FrozenGarmentCapture
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File

/** UI fixtures exercise editing and handoff, never claim real camera/AR scale validation. */
class CardlessCaptureUiTest {
    @get:Rule val compose = createAndroidComposeRule<AccountPreviewActivity>()
    private fun fixture(): FrozenGarmentCapture = FrozenGarmentCapture(
        Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888).apply { eraseColor(android.graphics.Color.LTGRAY) },
        FrozenGarmentPlane(Pose(floatArrayOf(0f, 1f, 0f), floatArrayOf(-.70710677f, 0f, 0f, .70710677f)),
            Pose.IDENTITY, listOf(-1f to -1f, 1f to -1f, 1f to 1f, -1f to 1f),
            floatArrayOf(256f, 256f), floatArrayOf(128f, 128f), 256, 256, 0), "ui-fixture-only", 1L)

    @Test fun skirtManualPointsRequireConfirmationAndPreserveItsThreeMeasurementKeys() {
        var result: CardlessGarmentResult? = null
        compose.setContent { CardlessGarmentCapture("skirt", {}, { result = it }, fixture()) }
        val canvas = compose.onNodeWithTag("camera-ar-frozen-photo")
        listOf(.2f to .25f, .8f to .25f, .15f to .45f, .85f to .45f, .5f to .25f, .5f to .9f).forEach { (x, y) ->
            canvas.performTouchInput { click(Offset(width * x, height * y)) }
        }
        compose.onNodeWithTag("camera-ar-apply").performScrollTo().assertIsNotEnabled()
        compose.onNodeWithText("봉제선과 측정 기준을 확인했어요").performScrollTo().performClick()
        compose.onNodeWithTag("camera-ar-apply").performScrollTo().assertIsEnabled()
        capture("cardless-skirt-review")
        compose.onNodeWithTag("camera-ar-apply").performClick()
        compose.runOnIdle {
            val measured = requireNotNull(result)
            assertEquals(setOf("waist_width", "hip_width", "total_length"), measured.centimeters.keys)
            assertEquals(60.0, requireNotNull(measured.centimeters["waist_width"]), .1)
            assertEquals("ar_plane", measured.metadata["source"])
        }
    }

    @Test fun cancelAndUndoDoNotProduceAMeasurement() {
        var measured = false
        var canceled = false
        compose.setContent { CardlessGarmentCapture("tshirt", { canceled = true }, { measured = true }, fixture()) }
        compose.onNodeWithTag("camera-ar-frozen-photo").performTouchInput { click(center) }
        compose.onNodeWithText("마지막 점 취소").performScrollTo().performClick()
        capture("cardless-manual-points")
        compose.onNodeWithText("닫기 · 직접 입력으로 돌아가기").performScrollTo().performClick()
        compose.runOnIdle { assertTrue(canceled); assertFalse(measured) }
    }
    private fun capture(name: String) {
        val file = File(compose.activity.getExternalFilesDir(null), "$name.png")
        file.outputStream().use { compose.onNodeWithTag("camera-ar-dialog").captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
