package com.inseong.coordit.ui.fitlab.camera

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.ar.core.Session
import com.inseong.coordit.data.fitlab.camera.ARCoreGarmentMeasurement
import com.inseong.coordit.data.fitlab.camera.GarmentMeasurementPolicy
import com.inseong.coordit.ui.components.CoorditButton
import com.inseong.coordit.ui.components.CoorditText
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography

/** Result is reviewed through the existing closet form; capture never performs a save or debit. */
data class CardlessGarmentResult(val category: String, val centimeters: Map<String, Double>,
                                 val bitmap: Bitmap, val metadata: Map<String, String>,
                                 val segments: List<ARCoreGarmentMeasurement.Segment> = emptyList())

private data class PhotoPoint(val x: Float, val y: Float)

@Composable
internal fun CardlessGarmentCapture(category: String, onCancel: () -> Unit, onMeasured: (CardlessGarmentResult) -> Unit,
    initialCapture: FrozenGarmentCapture? = null) {
    val context = LocalContext.current
    var permission by remember { mutableStateOf(context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val permissionRequest = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { permission = it }
    var frozen by remember { mutableStateOf(initialCapture) }
    var ready by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("옷을 바닥에 평평하게 펴주세요.") }
    var shutter by remember { mutableStateOf<(() -> Unit)?>(null) }
    var points by remember(frozen) { mutableStateOf<List<PhotoPoint>>(emptyList()) }
    var confirmed by remember(frozen, points) { mutableStateOf(false) }
    val dimensions = remember(category) { GarmentMeasurementPolicy.dimensions(category) }
    val current = frozen
    val values = if (current != null && points.size == dimensions.size * 2) {
        val world = points.map { current.geometry.worldPoint(it.x, it.y) }
        if (world.any { it == null }) null else dimensions.mapIndexed { index, key ->
            key to GarmentMeasurementPolicy.centimeters(requireNotNull(world[index * 2]), requireNotNull(world[index * 2 + 1]))
        }.toMap().takeIf { sizes -> sizes.all { (key, value) -> GarmentMeasurementPolicy.plausible(key, value) } }
    } else null
    LaunchedEffect(Unit) { if (!permission && frozen == null) permissionRequest.launch(Manifest.permission.CAMERA) }
    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().testTag("camera-ar-dialog").background(AppColors.appBackground).systemBarsPadding()
            .verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CoorditText("카드 없이 실측 · 실험 기능", CoorditTypography.gmarketBold(20f).copy(color = AppColors.ink))
            CoorditText(message, CoorditTypography.gmarketMedium(13f).copy(color = AppColors.ink))
            if (!permission && current == null) {
                CoorditButton("카메라 권한 허용", { permissionRequest.launch(Manifest.permission.CAMERA) })
            } else if (current == null) {
                LiveCamera(context, onStatus = { text, stable -> message = text; ready = stable },
                    onShutter = { shutter = it }, onCapture = { frozen = it; message = "측정 부위의 두 끝점을 차례로 눌러주세요. 점을 끌어 보정할 수 있어요." })
                CoorditButton("평면 위의 옷 촬영", { shutter?.invoke() }, enabled = ready, modifier = Modifier.testTag("camera-ar-shutter"))
            } else {
                val next = dimensions.getOrNull(points.size / 2)
                CoorditText(next?.let { "${dimensionTitle(it)} · ${points.size % 2 + 1}/2 끝점" } ?: "모든 측정점을 확인해주세요.",
                    CoorditTypography.gmarketMedium(14f).copy(color = AppColors.ink))
                Box(Modifier.fillMaxWidth().aspectRatio(current.bitmap.width.toFloat() / current.bitmap.height)) {
                    Image(current.bitmap.asImageBitmap(), "측정 사진", modifier = Modifier.fillMaxSize())
                    Canvas(Modifier.fillMaxSize().testTag("camera-ar-frozen-photo")
                        .pointerInput(current, points) { detectTapGestures { location ->
                            if (points.size < dimensions.size * 2) {
                                val point = PhotoPoint(location.x / size.width, location.y / size.height)
                                if (current.geometry.worldPoint(point.x, point.y) != null) points = points + point
                                else message = "인식된 바닥 안의 측정점을 눌러주세요. 평면이 부족하면 다시 촬영해주세요."
                            }
                        } }.pointerInput(current, points.size) {
                            var dragging: Int? = null
                            detectDragGestures(onDragStart = { position ->
                                dragging = points.indices.minByOrNull { index ->
                                    val p = points[index]; (Offset(p.x * size.width, p.y * size.height) - position).getDistanceSquared()
                                }?.takeIf { index -> (Offset(points[index].x * size.width, points[index].y * size.height) - position).getDistance() <= 32.dp.toPx() }
                            }, onDragEnd = { dragging = null }, onDragCancel = { dragging = null }) { change, _ ->
                                val index = dragging
                                if (index != null) {
                                    val point = PhotoPoint(change.position.x / size.width, change.position.y / size.height)
                                    if (current.geometry.worldPoint(point.x, point.y) != null) {
                                        points = points.mapIndexed { i, previous -> if (i == index) point else previous }
                                    }
                                    change.consume()
                                }
                            }
                        }) {
                        points.forEachIndexed { index, point ->
                            val center = Offset(point.x * size.width, point.y * size.height)
                            if (index % 2 == 1) {
                                val previous = points[index - 1]
                                drawLine(AppColors.ink, Offset(previous.x * size.width, previous.y * size.height), center, 2.dp.toPx())
                            }
                            drawCircle(Color.White, 8.dp.toPx(), center)
                            drawCircle(AppColors.ink, 5.dp.toPx(), center)
                        }
                    }
                }
                if (values != null) {
                    CoorditText(values.entries.joinToString(" · ") { "${dimensionTitle(it.key)} ${"%.1f".format(java.util.Locale.US, it.value)} cm" },
                        CoorditTypography.gmarketMedium(13f).copy(color = AppColors.ink))
                    CoorditButton(if (confirmed) "측정 기준 확인됨" else "봉제선과 측정 기준을 확인했어요", { confirmed = !confirmed }, secondary = true)
                    CoorditButton("옷장 입력에 적용", {
                        onMeasured(CardlessGarmentResult(category, values, current.bitmap, mapOf("source" to "ar_plane",
                            "measurement_status" to "measured", "ar_frame_id" to current.frameId,
                            "ar_frame_timestamp_ns" to current.timestamp.toString(), "tracking_quality" to "tracking",
                            "ar_plane_stable_seconds" to current.stableSeconds.toString(),
                            "ar_camera_motion_baseline_meters" to current.cameraBaselineMeters.toString(),
                            "coordinate_system" to "upright_rgb_normalized_top_left", "correction_status" to "manual_landmarks"),
                            dimensions.mapIndexed { index, key -> ARCoreGarmentMeasurement.Segment(key,
                                requireNotNull(current.geometry.worldPoint(points[index * 2].x, points[index * 2].y)),
                                requireNotNull(current.geometry.worldPoint(points[index * 2 + 1].x, points[index * 2 + 1].y)),
                                requireNotNull(values[key])) }))
                    }, enabled = confirmed, modifier = Modifier.testTag("camera-ar-apply"))
                } else if (points.size == dimensions.size * 2) {
                    CoorditText("측정 범위를 벗어났어요. 점을 끌어서 다시 맞춰주세요.", CoorditTypography.gmarketMedium(13f).copy(color = AppColors.danger))
                }
                CoorditButton("마지막 점 취소", { points = points.dropLast(1) }, secondary = true, enabled = points.isNotEmpty())
                CoorditButton("다시 촬영", { frozen = null; ready = false }, secondary = true)
            }
            CoorditButton("닫기 · 직접 입력으로 돌아가기", onCancel, secondary = true)
        }
    }
}

@Composable
private fun LiveCamera(context: Context, onStatus: (String, Boolean) -> Unit,
                       onShutter: (() -> Unit) -> Unit, onCapture: (FrozenGarmentCapture) -> Unit) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var session by remember { mutableStateOf<Session?>(null) }
    var surface by remember { mutableStateOf<ARCoreCameraSurface?>(null) }
    val activity = remember(context) {
        var candidate = context
        while (candidate is ContextWrapper && candidate !is Activity) candidate = candidate.baseContext
        candidate as? Activity
    }
    DisposableEffect(lifecycle, activity) {
        fun setup() {
            if (session == null && activity != null) {
                when (val result = ARCoreGarmentMeasurement.createSession(activity)) {
                    is ARCoreGarmentMeasurement.Setup.Ready -> session = result.session
                    is ARCoreGarmentMeasurement.Setup.Unavailable -> onStatus("AR을 사용할 수 없어요 (${result.reason}). 직접 입력으로 돌아갈 수 있어요.", false)
                }
            }
        }
        setup()
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> { setup(); surface?.resumeCamera() }
                Lifecycle.Event.ON_PAUSE -> surface?.pauseCamera()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer); surface?.closeCamera() ?: session?.close(); surface = null }
    }
    val currentSession = session
    if (currentSession != null && activity != null) AndroidView(factory = {
        ARCoreCameraSurface(activity, currentSession, onStatus, onCapture).also { camera ->
            surface = camera; onShutter(camera::requestCapture)
            if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) camera.resumeCamera()
        }
    }, modifier = Modifier.fillMaxWidth().height(400.dp))
}

private fun dimensionTitle(key: String): String = when (key) {
    "shoulder_width" -> "어깨"; "chest_width" -> "가슴 단면"; "total_length" -> "총장"; "sleeve_length" -> "소매"
    "waist_width" -> "허리 단면"; "hip_width" -> "엉덩이 단면"; "rise" -> "밑위"; "outseam" -> "아웃심"; else -> key
}
