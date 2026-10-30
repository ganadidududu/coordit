package com.inseong.coordit.data.fitlab.camera

import com.google.ar.core.Pose
import org.junit.Assert.*
import org.junit.Test

class FrozenGarmentPlaneTest {
    private fun plane(rotation: Int = 0, focal: FloatArray = floatArrayOf(1000f, 1000f)): FrozenGarmentPlane = FrozenGarmentPlane(
        Pose(floatArrayOf(0f, 1f, 0f), floatArrayOf(-.70710677f, 0f, 0f, .70710677f)), Pose.IDENTITY,
        listOf(-1f to -1f, 1f to -1f, 1f to 1f, -1f to 1f), focal, floatArrayOf(500f, 500f), 1000, 1000, rotation)

    @Test fun nonLidarCapturedPlaneMeasuresFiftyCentimeters() {
        val frozen = plane()
        val a = requireNotNull(frozen.worldPoint(.25f, .5f)); val b = requireNotNull(frozen.worldPoint(.75f, .5f))
        assertEquals(50.0, GarmentMeasurementPolicy.centimeters(a, b), .001)
    }
    @Test fun rotationsUseSensorCoordinatesAndSnapshotsCopyCalibration() {
        val focal = floatArrayOf(1000f, 1000f)
        val frozen = plane(focal = focal)
        focal[0] = 1f
        val expected = requireNotNull(frozen.worldPoint(.25f, .5f))
        listOf(90 to (.5f to .25f), 180 to (.75f to .5f), 270 to (.5f to .75f)).forEach { (rotation, point) ->
            val actual = requireNotNull(plane(rotation).worldPoint(point.first, point.second))
            expected.zip(actual).forEach { (a, b) -> assertEquals(a.toDouble(), b.toDouble(), .0001) }
        }
        assertNull(frozen.worldPoint(Float.NaN, .5f))
    }
    @Test fun knownLengthsRemainMetricAcrossHeightTiltAndImageRotation() {
        var checked = 0
        val segments = listOf(
            floatArrayOf(-.3f, 0f, 0f) to floatArrayOf(.3f, 0f, 0f),
            floatArrayOf(-.21f, 0f, -.25f) to floatArrayOf(.21f, 0f, -.25f),
            floatArrayOf(0f, 0f, -.4f) to floatArrayOf(0f, 0f, .4f),
            floatArrayOf(.2f, 0f, -.3f) to floatArrayOf(.45f, 0f, -.05f),
            floatArrayOf(-.35f, 0f, .1f) to floatArrayOf(.35f, 0f, .1f))
        for (height in listOf(.65f, 1.1f, 1.8f)) for (tilt in listOf(0f, .25f, .5f)) {
            val angle = tilt - Math.PI.toFloat() / 2
            val camera = Pose(floatArrayOf(0f, height, height * kotlin.math.tan(tilt)),
                floatArrayOf(kotlin.math.sin(angle / 2), 0f, 0f, kotlin.math.cos(angle / 2)))
            for (rotation in listOf(0, 90, 180, 270)) {
                val frozen = FrozenGarmentPlane(camera, Pose.IDENTITY,
                    listOf(-1f to -1f, 1f to -1f, 1f to 1f, -1f to 1f), floatArrayOf(1200f, 1180f),
                    floatArrayOf(946f, 716f), 1920, 1440, rotation)
                fun project(point: FloatArray): Pair<Float, Float> {
                    val dy = point[1] - height; val dz = point[2] - height * kotlin.math.tan(tilt)
                    val depth = -dy * kotlin.math.cos(tilt) - dz * kotlin.math.sin(tilt)
                    val x = (946f + 1200f * point[0] / depth) / 1920
                    val y = (716f - 1180f * (dy * kotlin.math.sin(tilt) - dz * kotlin.math.cos(tilt)) / depth) / 1440
                    return when (rotation) { 90 -> 1-y to x; 180 -> 1-x to 1-y; 270 -> y to 1-x; else -> x to y }
                }
                for ((a, b) in segments) {
                    val pa = project(a); val pb = project(b)
                    if (listOf(pa.first, pa.second, pb.first, pb.second).any { it !in 0f..1f }) continue
                    val actual = GarmentMeasurementPolicy.centimeters(requireNotNull(frozen.worldPoint(pa.first, pa.second)),
                        requireNotNull(frozen.worldPoint(pb.first, pb.second)))
                    assertEquals(GarmentMeasurementPolicy.centimeters(a.toList(), b.toList()), actual, .003)
                    checked++
                }
            }
        }
        assertTrue(checked >= 160)
    }

}
