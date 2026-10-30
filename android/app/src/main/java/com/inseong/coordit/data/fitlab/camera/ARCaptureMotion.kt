package com.inseong.coordit.data.fitlab.camera

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/** Actual translational baseline and full 3-axis angular speed; accumulated jitter is not parallax. */
internal class ARCaptureMotion {
    private var origin: FloatArray? = null
    private var previousPosition: FloatArray? = null
    private var previousRotation: FloatArray? = null
    private var previousTimestamp = 0L
    var baselineMeters = 0.0
        private set
    fun reset() { origin = null; previousPosition = null; previousRotation = null; previousTimestamp = 0; baselineMeters = 0.0 }

    fun matches(position: FloatArray, rotation: FloatArray, timestamp: Long): Boolean = timestamp == previousTimestamp &&
        previousPosition?.contentEquals(position) == true && previousRotation?.contentEquals(rotation) == true

    fun observe(position: FloatArray, rotation: FloatArray, timestamp: Long): Boolean {
        if (position.size != 3 || rotation.size != 4 || position.any { !it.isFinite() } || rotation.any { !it.isFinite() } ||
            timestamp <= 0 || timestamp <= previousTimestamp) { reset(); return false }
        fun distance(a: FloatArray, b: FloatArray) = sqrt(a.indices.sumOf { (a[it] - b[it]).toDouble().let { d -> d * d } })
        val reference = origin ?: position.copyOf().also { origin = it }
        baselineMeters = maxOf(baselineMeters, distance(reference, position))
        val before = previousPosition
        val old = previousRotation
        val duration = (timestamp - previousTimestamp) / 1e9
        val still = if (before != null && old != null && duration > 0) {
            // Relative quaternion conj(old) * rotation; atan2 preserves precision for tiny rotations.
            val normA = sqrt(old.sumOf { it.toDouble() * it }); val normB = sqrt(rotation.sumOf { it.toDouble() * it })
            if (normA < .99 || normB < .99) false else {
                val a = DoubleArray(4) { old[it] / normA }; val b = DoubleArray(4) { rotation[it] / normB }
                val x = a[3] * b[0] - a[0] * b[3] - a[1] * b[2] + a[2] * b[1]
                val y = a[3] * b[1] + a[0] * b[2] - a[1] * b[3] - a[2] * b[0]
                val z = a[3] * b[2] - a[0] * b[1] + a[1] * b[0] - a[2] * b[3]
                val w = a.indices.sumOf { a[it] * b[it] }
                val angle = 2 * atan2(sqrt(x * x + y * y + z * z), abs(w))
                distance(before, position) / duration < .03 && angle / duration < .04
            }
        } else false
        previousPosition = position.copyOf(); previousRotation = rotation.copyOf(); previousTimestamp = timestamp
        return still
    }
}
