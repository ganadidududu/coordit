package com.inseong.coordit.ui.fitlab.camera

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Session
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.NotYetAvailableException
import com.google.ar.core.exceptions.SessionPausedException
import com.inseong.coordit.data.fitlab.camera.ARCoreGarmentMeasurement
import com.inseong.coordit.data.fitlab.camera.FrozenGarmentPlane
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

internal data class FrozenGarmentCapture(val bitmap: Bitmap, val geometry: FrozenGarmentPlane,
                                        val frameId: String, val timestamp: Long,
                                        val stableSeconds: Double = 0.0, val cameraBaselineMeters: Double = 0.0)

/** The GL thread captures CPU pixels, intrinsics and poses synchronously from one Frame. */
internal class ARCoreCameraSurface(
    private val activity: Activity, private val session: Session,
    private val status: (String, Boolean) -> Unit, private val captured: (FrozenGarmentCapture) -> Unit,
) : GLSurfaceView(activity), GLSurfaceView.Renderer {
    private val shutter = AtomicBoolean(false)
    private val quality = ARCoreGarmentMeasurement()
    private var texture = 0
    private var program = 0
    private var viewportWidth = 1
    private var viewportHeight = 1
    private val vertices = buffer(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
    private val uv = buffer(FloatArray(8))
    private var lastReady: Boolean? = null
    @Volatile private var active = false
    init { setEGLContextClientVersion(2); preserveEGLContextOnPause = true; setRenderer(this) }

    fun requestCapture() { shutter.set(true) }
    fun resumeCamera() {
        try { session.resume(); active = true; onResume() }
        catch (error: CameraNotAvailableException) { status("카메라를 사용할 수 없어요. 직접 입력으로 돌아갈 수 있어요.", false) }
    }
    fun pauseCamera() { active = false; onPause(); session.pause(); quality.reset(); lastReady = null }
    fun closeCamera() { pauseCamera(); session.close() }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        val names = IntArray(1); GLES20.glGenTextures(1, names, 0); texture = names[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        fun shader(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type); GLES20.glShaderSource(shader, source); GLES20.glCompileShader(shader)
            val compiled = IntArray(1); GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
            check(compiled[0] == GLES20.GL_TRUE) { "Camera shader compilation failed" }
            return shader
        }
        val vertex = shader(GLES20.GL_VERTEX_SHADER, "attribute vec2 position; attribute vec2 uv; varying vec2 tex; void main(){gl_Position=vec4(position,0.,1.); tex=uv;}")
        val fragment = shader(GLES20.GL_FRAGMENT_SHADER, "#extension GL_OES_EGL_image_external : require\nprecision mediump float; uniform samplerExternalOES camera; varying vec2 tex; void main(){gl_FragColor=texture2D(camera,tex);}")
        program = GLES20.glCreateProgram(); GLES20.glAttachShader(program, vertex); GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program); GLES20.glDeleteShader(vertex); GLES20.glDeleteShader(fragment)
        val linked = IntArray(1); GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        check(linked[0] == GLES20.GL_TRUE) { "Camera program linking failed" }
    }
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width; viewportHeight = height; GLES20.glViewport(0, 0, width, height)
    }
    override fun onDrawFrame(gl: GL10?) {
        if (!active) return
        try {
            session.setDisplayGeometry(display.rotation, viewportWidth, viewportHeight)
            session.setCameraTextureName(texture)
            val frame = session.update()
            if (frame.timestamp == 0L) return
            vertices.position(0); uv.position(0)
            frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, vertices, Coordinates2d.TEXTURE_NORMALIZED, uv)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT); GLES20.glUseProgram(program)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0); GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "camera"), 0)
            val p = GLES20.glGetAttribLocation(program, "position"); val t = GLES20.glGetAttribLocation(program, "uv")
            vertices.position(0); uv.position(0)
            GLES20.glVertexAttribPointer(p, 2, GLES20.GL_FLOAT, false, 0, vertices); GLES20.glEnableVertexAttribArray(p)
            GLES20.glVertexAttribPointer(t, 2, GLES20.GL_FLOAT, false, 0, uv); GLES20.glEnableVertexAttribArray(t)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GLES20.glDisableVertexAttribArray(p); GLES20.glDisableVertexAttribArray(t)
            val plane = quality.readyPlane(frame, ARCoreGarmentMeasurement.Point(viewportWidth / 2f, viewportHeight / 2f))
            if (lastReady != (plane != null)) {
                lastReady = plane != null
                post { status(if (plane != null) "좋아요. 옷을 촬영해주세요." else "카메라를 천천히 움직여 바닥을 인식한 뒤 잠깐 고정해주세요.", plane != null) }
            }
            if (shutter.getAndSet(false)) {
                if (plane == null) { post { status("평면과 카메라가 안정되면 다시 촬영해주세요.", false) }; return }
                frame.acquireCameraImage().use { image ->
                    check(image.timestamp == frame.androidCameraTimestamp) { "Image and AR pose are different sensor frames" }
                    check(image.cropRect == Rect(0, 0, image.width, image.height)) { "Cropped sensor image needs separate intrinsics" }
                    val intrinsics = frame.camera.imageIntrinsics
                    check(intrinsics.imageDimensions.contentEquals(intArrayOf(image.width, image.height))) { "Sensor coordinates disagree" }
                    val orientation = activity.getSystemService(CameraManager::class.java)
                        .getCameraCharacteristics(session.cameraConfig.cameraId).get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                    val rotation = (orientation - display.rotation * 90 + 360) % 360
                    val boundary = plane.polygon.duplicate(); boundary.rewind()
                    val polygon = mutableListOf<Pair<Float, Float>>()
                    while (boundary.remaining() >= 2) polygon += boundary.get() to boundary.get()
                    val geometry = FrozenGarmentPlane(frame.camera.pose, plane.centerPose, polygon,
                        intrinsics.focalLength, intrinsics.principalPoint, image.width, image.height, rotation)
                    val raw = yuvBitmap(image)
                    val upright = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, Matrix().apply { postRotate(rotation.toFloat()) }, true)
                    if (upright !== raw) raw.recycle()
                    val snapshot = FrozenGarmentCapture(upright, geometry, UUID.randomUUID().toString(), frame.timestamp,
                        quality.stablePlaneSeconds, quality.cameraMotionBaselineMeters)
                    post { captured(snapshot) }
                }
            }
        } catch (error: NotYetAvailableException) { lastReady = null; post { status("사진을 준비하지 못했어요. 다시 촬영해주세요.", false) } }
        catch (error: CameraNotAvailableException) { active = false; post { status("카메라 연결이 중단됐어요. 화면을 다시 열어주세요.", false) } }
        catch (error: SessionPausedException) { quality.reset(); lastReady = null }
        catch (error: android.hardware.camera2.CameraAccessException) { lastReady = null; post { status("카메라 설정을 확인하지 못했어요. 직접 입력으로 돌아갈 수 있어요.", false) } }
        catch (error: IllegalStateException) { shutter.set(false); lastReady = null; post { status("촬영 좌표를 확인하지 못했어요. 직접 입력으로 돌아갈 수 있어요.", false) } }
    }
    private fun yuvBitmap(image: android.media.Image): Bitmap {
        val width = image.width; val height = image.height
        val bytes = ByteArray(width * height * 3 / 2)
        val planes = image.planes
        for (y in 0 until height) for (x in 0 until width) bytes[y * width + x] = planes[0].buffer.get(y * planes[0].rowStride + x * planes[0].pixelStride)
        var offset = width * height
        for (y in 0 until height / 2) for (x in 0 until width / 2) {
            bytes[offset++] = planes[2].buffer.get(y * planes[2].rowStride + x * planes[2].pixelStride)
            bytes[offset++] = planes[1].buffer.get(y * planes[1].rowStride + x * planes[1].pixelStride)
        }
        val encoded = ByteArrayOutputStream().use { stream ->
            check(YuvImage(bytes, ImageFormat.NV21, width, height, null).compressToJpeg(Rect(0, 0, width, height), 90, stream))
            stream.toByteArray()
        }
        return requireNotNull(BitmapFactory.decodeByteArray(encoded, 0, encoded.size))
    }
    private fun buffer(values: FloatArray) = ByteBuffer.allocateDirect(values.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(values); position(0) }
}
