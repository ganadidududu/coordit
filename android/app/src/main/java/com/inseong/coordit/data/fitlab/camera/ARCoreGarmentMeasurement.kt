package com.inseong.coordit.data.fitlab.camera

import android.app.Activity
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.inseong.coordit.BuildConfig
import kotlin.math.sqrt

/** Host owns camera permission, GL camera texture, display geometry and resume/pause/close.
 * All methods are called on the session's GL thread. Coordinates belong to this Frame's viewport.
 * Async AI results MUST be reprojected from saved intrinsics/pose, never fed to a later Frame.
 */
class ARCoreGarmentMeasurement {
    data class Point(val x: Float, val y: Float)
    data class Capture(val category: String, val frame: Frame, val endpoints: List<Point>)
    data class Segment(val key: String, val startMeters: List<Float>, val endMeters: List<Float>, val centimeters: Double)
    data class Evidence(val frameTimestampNanos: Long, val trackingQuality: String, val stablePlaneSeconds: Double,
                        val cameraPose: List<Float>, val focalLength: List<Float>, val principalPoint: List<Float>,
                        val coordinateSystem: String = "arcore_viewport_pixels", val corrected: Boolean = false)
    sealed interface Result {
        data class Measured(val segments: List<Segment>, val evidence: Evidence, val method: String = "arPlane") : Result
        data class Rejected(val reason: String, val fallback: String = "manual_input") : Result
    }
    sealed interface Setup {
        data class Ready(val session: Session) : Setup
        data class Unavailable(val reason: String) : Setup
    }
    companion object {
        /** Call only after CAMERA permission is granted; ARCore installation may prompt the user. */
        fun createSession(activity: Activity): Setup {
            if (!BuildConfig.CARDLESS_AR_ENABLED) return Setup.Unavailable("feature_disabled")
            val apk = ArCoreApk.getInstance()
            val availability = apk.checkAvailability(activity)
            if (availability.isTransient) return Setup.Unavailable("availability_pending")
            if (!availability.isSupported) return Setup.Unavailable("arcore_unsupported")
            return try {
                if (apk.requestInstall(activity, true) == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                    Setup.Unavailable("installation_requested")
                } else {
                    val session = Session(activity)
                    session.configure(Config(session).apply { planeFindingMode = Config.PlaneFindingMode.HORIZONTAL })
                    Setup.Ready(session)
                }
            } catch (error: com.google.ar.core.exceptions.UnavailableException) {
                Setup.Unavailable("arcore_unavailable_${error.javaClass.simpleName}")
            } catch (error: SecurityException) {
                Setup.Unavailable("camera_permission_required")
            }
        }
    }
    private var plane: Plane? = null
    private var planeOrigin: FloatArray? = null
    private var firstTimestamp = 0L
    private var lastTimestamp = 0L
    private val cameraMotion = ARCaptureMotion()
    private var stillSince = 0L

    val stablePlaneSeconds: Double get() = (lastTimestamp - firstTimestamp) / 1e9
    val cameraMotionBaselineMeters: Double get() = cameraMotion.baselineMeters

    fun reset() {
        plane = null; planeOrigin = null; firstTimestamp = 0; lastTimestamp = 0
        cameraMotion.reset(); stillSince = 0
    }

    /** Manual or heuristic endpoints are all hit-tested synchronously against ONE captured Frame. */
    fun measure(capture: Capture): Result {
        val frame = capture.frame
        if (frame.camera.trackingState != TrackingState.TRACKING) { reset(); return Result.Rejected("tracking_unavailable") }
        if (capture.category !in GarmentMeasurementPolicy.categories) return Result.Rejected("unsupported_category")
        val keys = GarmentMeasurementPolicy.dimensions(capture.category)
        if (capture.endpoints.size != keys.size * 2 || capture.endpoints.any { !it.x.isFinite() || !it.y.isFinite() || it.x < 0 || it.y < 0 }) {
            return Result.Rejected("landmarks_missing")
        }
        val hits = capture.endpoints.map { point ->
            frame.hitTest(point.x, point.y).firstOrNull { hit ->
                val candidate = hit.trackable as? Plane
                candidate != null && candidate.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                    candidate.trackingState == TrackingState.TRACKING && candidate.subsumedBy == null && candidate.isPoseInPolygon(hit.hitPose)
            } ?: return Result.Rejected("plane_not_found")
        }
        val selected = hits.first().trackable as Plane
        if (hits.any { it.trackable != selected }) return Result.Rejected("different_planes")
        val down = frame.camera.pose.getTransformedAxis(2, 1f)
        if (down[1] < .75f) return Result.Rejected("camera_tilted")
        if (!observe(selected, frame)) return Result.Rejected("plane_or_scale_unstable")
        val segments = keys.mapIndexed { index, key ->
            val a = hits[index * 2].hitPose.translation.toList()
            val b = hits[index * 2 + 1].hitPose.translation.toList()
            val cm = GarmentMeasurementPolicy.centimeters(a, b)
            if (!GarmentMeasurementPolicy.plausible(key, cm)) return Result.Rejected("invalid_$key")
            Segment(key, a, b, cm)
        }
        val intrinsics = frame.camera.imageIntrinsics
        return Result.Measured(segments, Evidence(frame.timestamp, "tracking", (frame.timestamp - firstTimestamp) / 1e9,
            frame.camera.pose.let { it.translation.toList() + it.rotationQuaternion.toList() },
            intrinsics.focalLength.toList(), intrinsics.principalPoint.toList()))
    }

    /** Observe the center plane on each rendered Frame before freezing a raw camera image. */
    fun readyPlane(frame: Frame, center: Point): Plane? {
        if (frame.camera.trackingState != TrackingState.TRACKING) { reset(); return null }
        if (frame.camera.pose.getTransformedAxis(2, 1f)[1] < .75f) { reset(); return null }
        val candidate = frame.hitTest(center.x, center.y).firstOrNull { hit ->
            val p = hit.trackable as? Plane
            p != null && p.type == Plane.Type.HORIZONTAL_UPWARD_FACING && p.trackingState == TrackingState.TRACKING &&
                p.subsumedBy == null && p.extentX >= .25f && p.extentZ >= .25f && p.isPoseInPolygon(hit.hitPose)
        }?.trackable as? Plane ?: run { reset(); return null }
        return candidate.takeIf { observe(it, frame) }
    }

    private fun observe(candidate: Plane, frame: Frame): Boolean {
        val origin = candidate.centerPose.translation
        val position = frame.camera.pose.translation
        fun distance(a: FloatArray, b: FloatArray) = sqrt(a.indices.sumOf { (a[it] - b[it]).toDouble().let { d -> d * d } })
        if (frame.timestamp < lastTimestamp) { reset(); return false }
        if (frame.timestamp == lastTimestamp) return candidate == plane &&
            cameraMotion.matches(position, frame.camera.pose.rotationQuaternion, frame.timestamp) &&
            frame.timestamp - firstTimestamp >= 1_000_000_000L && cameraMotion.baselineMeters >= .03 &&
            stillSince > 0 && frame.timestamp - stillSince >= 300_000_000L
        if (candidate != plane || (lastTimestamp > 0 && frame.timestamp - lastTimestamp > 500_000_000L) ||
            planeOrigin?.let { distance(it, origin) > .01 } == true) reset()
        plane = candidate
        planeOrigin = planeOrigin ?: origin.copyOf()
        if (firstTimestamp == 0L) firstTimestamp = frame.timestamp
        val still = cameraMotion.observe(position, frame.camera.pose.rotationQuaternion, frame.timestamp)
        stillSince = if (still) { if (stillSince == 0L) frame.timestamp else stillSince } else 0L
        lastTimestamp = frame.timestamp
        return frame.timestamp - firstTimestamp >= 1_000_000_000L && cameraMotion.baselineMeters >= .03 &&
            stillSince > 0 && frame.timestamp - stillSince >= 300_000_000L
    }
}
