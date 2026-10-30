package com.inseong.coordit.data.fitlab.camera

import com.google.ar.core.Pose
import kotlin.math.abs
import kotlin.math.sqrt

/** Immutable sensor calibration; image points use upright, unmirrored, normalized coordinates. */
class FrozenGarmentPlane(
    cameraPose: Pose, planePose: Pose, boundaryXZ: List<Pair<Float, Float>>,
    focal: FloatArray, principal: FloatArray, private val width: Int, private val height: Int,
    private val rotationDegrees: Int,
) {
    private val camera = Pose(cameraPose.translation.copyOf(), cameraPose.rotationQuaternion.copyOf())
    private val plane = Pose(planePose.translation.copyOf(), planePose.rotationQuaternion.copyOf())
    private val boundary = boundaryXZ.toList()
    private val focal = focal.copyOf()
    private val principal = principal.copyOf()

    fun worldPoint(x: Float, y: Float): List<Float>? {
        if (!x.isFinite() || !y.isFinite() || x !in 0f..1f || y !in 0f..1f || width <= 0 || height <= 0 ||
            focal.size != 2 || principal.size != 2 || focal.any { !it.isFinite() || it <= 0 }) return null
        val (sensorX, sensorY) = when (rotationDegrees) {
            0 -> x to y
            90 -> y to 1 - x
            180 -> 1 - x to 1 - y
            270 -> 1 - y to x
            else -> return null
        }
        val origin = camera.translation
        val direction = camera.rotateVector(floatArrayOf((sensorX * width - principal[0]) / focal[0],
            -(sensorY * height - principal[1]) / focal[1], -1f))
        val norm = sqrt(direction.sumOf { it.toDouble() * it }).toFloat()
        for (i in direction.indices) direction[i] /= norm
        val normal = plane.getTransformedAxis(1, 1f)
        val denominator = direction.indices.sumOf { direction[it].toDouble() * normal[it] }.toFloat()
        if (abs(denominator) < .5) return null
        val center = plane.translation
        val distance = origin.indices.sumOf { (center[it] - origin[it]).toDouble() * normal[it] }.toFloat() / denominator
        if (!distance.isFinite() || distance !in .15f..3f) return null
        val result = FloatArray(3) { origin[it] + distance * direction[it] }
        val local = plane.inverse().transformPoint(result)
        var inside = false
        if (boundary.size < 3) return null
        boundary.indices.forEach { i ->
            val a = boundary[i]; val b = boundary[(i + 1) % boundary.size]
            if ((a.second > local[2]) != (b.second > local[2]) &&
                local[0] < (b.first - a.first) * (local[2] - a.second) / (b.second - a.second) + a.first) inside = !inside
        }
        return result.toList().takeIf { inside && it.all(Float::isFinite) }
    }
}
