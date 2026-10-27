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
}
