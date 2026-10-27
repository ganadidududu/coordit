package com.inseong.coordit.data.fitlab.camera

import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test

class ARCaptureMotionTest {
    @Test fun millimeterJitterIsNotAThreeCentimeterBaseline() {
        val quality = ARCaptureMotion()
        repeat(100) { index -> quality.observe(floatArrayOf(if (index % 2 == 0) 0f else .001f, 0f, 0f),
            floatArrayOf(0f, 0f, 0f, 1f), (index + 1) * 100_000_000L) }
        assertTrue(quality.baselineMeters < .003)
    }
    @Test fun pureRollAndDifferentFrameRatesUseAngularVelocity() {
        for (fps in listOf(10, 30, 60)) {
            val quality = ARCaptureMotion()
            quality.observe(floatArrayOf(0f, 0f, 0f), floatArrayOf(0f, 0f, 0f, 1f), 1_000_000_000)
            repeat(fps) { index ->
                val angle = (index + 1) * .1f / fps
                assertFalse(quality.observe(floatArrayOf(0f, 0f, 0f),
                    floatArrayOf(0f, 0f, sin(angle / 2), cos(angle / 2)), 1_000_000_000L + (index + 1) * 1_000_000_000L / fps))
            }
        }
    }
    @Test fun realTranslationThenStillnessRetainsAnActualBaselineAndCopiesInputs() {
        val quality = ARCaptureMotion()
        val point = floatArrayOf(0f, 0f, 0f)
        quality.observe(point, floatArrayOf(0f, 0f, 0f, 1f), 1_000_000_000)
        point[0] = .04f
        assertFalse(quality.observe(point, floatArrayOf(0f, 0f, 0f, 1f), 1_100_000_000))
        assertTrue(quality.observe(point, floatArrayOf(0f, 0f, 0f, 1f), 1_200_000_000))
        assertEquals(.04, quality.baselineMeters, .000001)
        quality.observe(point, floatArrayOf(0f, 0f, 0f, 1f), 1_150_000_000)
        assertEquals(0.0, quality.baselineMeters, .000001)
    }
}
