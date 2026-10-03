package com.inseong.coordit.ui.closet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.inseong.coordit.data.closet.ClosetOcr
import com.inseong.coordit.data.closet.OcrCell
import com.inseong.coordit.data.closet.OcrRow
import com.inseong.coordit.ui.components.CoorditButton
import com.inseong.coordit.ui.components.Pressable
import com.inseong.coordit.ui.theme.AppColors
import com.inseong.coordit.ui.theme.CoorditTypography
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.math.min

@Composable
fun ClosetPhotoInput(
    upper: Boolean,
    onRows: (List<OcrRow>) -> Unit,
    onGarment: (Bitmap) -> Unit,
    enabled: Boolean = true,
    scale: Float = 1f,
) {
    val scope = rememberCoroutineScope()
    val currentRows by rememberUpdatedState(onRows)
    val currentUpper by rememberUpdatedState(upper)
    var generation by remember { mutableIntStateOf(0) }
    var pending by remember { mutableStateOf<Bitmap?>(null) }
    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(upper) { generation++; pending = null; preview = null; busy = false; error = null }
    Column(verticalArrangement = Arrangement.spacedBy((ClosetDesign.sectionGap * scale).dp)) {
        ClosetPanel(scale, "사진 첨부", "사진을 고른 다음 표 부분만 정확히 잘라주세요.") {
            PhotoSourceButtons("사이즈표", enabled && !busy, upper.toString(),
                onImage = { pending = it }, onError = { error = it },
                scale = scale, slot = true, preview = preview)
        }
        if (busy) ClosetText("사이즈별 표를 읽는 중…", 11f, scale)
        error?.let { ClosetError(it, scale) }
        ClosetGarmentPhotoPicker(onPhoto = onGarment, enabled = enabled && !busy, scale = scale)
    }
    pending?.let { image ->
        SizeChartCropper(image, onCancel = { pending = null }, onConfirm = { cropped ->
            pending = null
            preview = cropped
            error = null
            busy = true
            currentRows(emptyList())
            val request = ++generation
            val requestUpper = upper
            scope.launch {
                try {
                    val cells = recognize(cropped)
                    val rows = withContext(Dispatchers.Default) { ClosetOcr.parse(cells, requestUpper) }
                    if (request == generation && requestUpper == currentUpper) {
                        currentRows(rows)
                        if (rows.isEmpty()) error = "표를 읽지 못했어요. 첫 행과 모든 사이즈 행을 포함해 다시 자르거나 직접 입력해 주세요."
                    }
                } catch (failure: Exception) {
                    if (failure is kotlinx.coroutines.CancellationException) throw failure
                    if (request == generation) error = "사진을 분석하지 못했어요. 선명한 표를 다시 선택하거나 직접 입력해 주세요."
                } finally {
                    if (request == generation) busy = false
                }
            }
        })
    }
}

@Composable
fun ClosetGarmentPhotoPicker(onPhoto: (Bitmap) -> Unit, enabled: Boolean = true, compact: Boolean = false, scale: Float = 1f) {
    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val controls: @Composable () -> Unit = {
        PhotoSourceButtons(if (compact) "옷 사진 추가하기" else "옷 사진 선택", enabled, "garment",
            onImage = { preview = it; error = null; onPhoto(it) }, onError = { error = it },
            scale = scale, compact = compact)
        error?.let { ClosetError(it, scale) }
    }
    if (compact) controls() else ClosetPanel(scale, "옷 사진 (선택)") {
        preview?.let { Image(it.asImageBitmap(), "선택한 옷 사진", Modifier.fillMaxWidth().height((140 * scale).dp)) }
        controls()
    }
}

@Composable
private fun PhotoSourceButtons(title: String, enabled: Boolean, identity: String, onImage: (Bitmap) -> Unit, onError: (String) -> Unit, scale: Float = 1f, slot: Boolean = false, preview: Bitmap? = null, compact: Boolean = false) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val currentImage by rememberUpdatedState(onImage)
    val currentError by rememberUpdatedState(onError)
    val currentIdentity by rememberUpdatedState(identity)
    var launchIdentity by rememberSaveable { mutableStateOf(identity) }
    var cameraUri by rememberSaveable { mutableStateOf<String?>(null) }
    var cameraPath by rememberSaveable { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    var sequence by remember { mutableIntStateOf(0) }
    fun receive(uri: Uri?, cleanup: File? = null) {
        if (uri == null || launchIdentity != currentIdentity) { cleanup?.delete(); return }
        val request = ++sequence
        val expected = launchIdentity
        loading = true
        scope.launch {
            try {
                val bitmap = withContext(Dispatchers.IO) { decodeImage(context, uri) }
                if (request == sequence && expected == currentIdentity) currentImage(bitmap)
            } catch (failure: Exception) {
                if (failure is kotlinx.coroutines.CancellationException) throw failure
                if (request == sequence && expected == currentIdentity) currentError("이미지를 읽을 수 없어요. 다른 사진을 선택해 주세요.")
            } finally { cleanup?.delete(); if (request == sequence) loading = false }
        }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { receive(it) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        receive(if (success) cameraUri?.let(Uri::parse) else null, cameraPath?.let(::File))
        cameraUri = null; cameraPath = null
    }
    val openPicker = {
        launchIdentity = identity
        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }
    Column(verticalArrangement = Arrangement.spacedBy((9 * scale).dp)) {
        if (slot) PhotoPickerSlot(title, preview, scale, enabled && !loading, openPicker)
        else if (compact) Pressable(openPicker, Modifier.fillMaxWidth().testTag("closet-garment-photo"), enabled && !loading, cornerRadius = ClosetDesign.actionRadius * scale) {
            Box(Modifier.fillMaxWidth().heightIn(min = (ClosetDesign.detailActionHeight * scale).dp).background(AppColors.panel).padding(horizontal = (ClosetDesign.smallGap * scale).dp), contentAlignment = Alignment.Center) {
                BasicText(title, style = CoorditTypography.gmarketMedium(10 * scale).copy(color = Color.Black))
            }
        } else CoorditButton(title, openPicker, secondary = true, enabled = enabled && !loading, height = 48 * scale, fontSize = ClosetDesign.bodyFont * scale)
        if (!compact) CoorditButton("카메라로 촬영", {
            try {
                val directory = File(context.cacheDir, "closet-camera").apply { mkdirs() }
                val file = File.createTempFile("capture-", ".jpg", directory)
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                cameraPath = file.absolutePath; cameraUri = uri.toString(); launchIdentity = identity
                camera.launch(uri)
            } catch (failure: Exception) {
                cameraPath?.let(::File)?.delete(); cameraPath = null; cameraUri = null
                currentError("카메라를 열 수 없어요. 사진 보관함에서 선택해 주세요.")
            }
        }, Modifier.testTag(if (slot) "closet-size-chart-camera" else "closet-garment-camera"), secondary = true, enabled = enabled && !loading, height = 48 * scale, fontSize = ClosetDesign.bodyFont * scale)
        if (loading) BasicText("사진을 불러오는 중…", style = CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted))
    }
}

@Composable
private fun PhotoPickerSlot(title: String, preview: Bitmap?, scale: Float, enabled: Boolean, onClick: () -> Unit) {
    Pressable(onClick, Modifier.fillMaxWidth().aspectRatio(3f / 4f).testTag("closet-size-chart-photo")
        .semantics { contentDescription = if (preview == null) "사이즈표 사진 선택" else "사이즈표 사진 변경" }, enabled, cornerRadius = ClosetDesign.fieldRadius * scale) {
        Box(Modifier.fillMaxSize().background(AppColors.closetField), contentAlignment = Alignment.Center) {
            if (preview != null) {
                Image(preview.asImageBitmap(), "선택한 사이즈표", Modifier.fillMaxSize())
                Box(Modifier.align(Alignment.BottomCenter).padding(bottom = (ClosetDesign.smallGap * scale).dp)
                    .background(AppColors.ink.copy(alpha = .82f), androidx.compose.foundation.shape.RoundedCornerShape(50))
                    .padding(horizontal = (10 * scale).dp, vertical = (6 * scale).dp)) {
                    BasicText("변경하기", style = CoorditTypography.gmarketBold(ClosetDesign.captionFont * scale).copy(color = Color.White))
                }
            } else Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((7 * scale).dp)) {
                Canvas(Modifier.size((25 * scale).dp)) {
                    drawCircle(AppColors.ink)
                    drawLine(Color.White, Offset(size.width * .32f, size.height / 2), Offset(size.width * .68f, size.height / 2), 2.5f * scale * density, StrokeCap.Round)
                    drawLine(Color.White, Offset(size.width / 2, size.height * .32f), Offset(size.width / 2, size.height * .68f), 2.5f * scale * density, StrokeCap.Round)
                }
                BasicText(title, style = CoorditTypography.gmarketBold(ClosetDesign.bodyFont * scale).copy(color = Color.Black))
                BasicText("선택 후 표 영역 자르기", style = CoorditTypography.gmarketMedium(8 * scale).copy(color = AppColors.ink.copy(alpha = .4f)))
            }
            Canvas(Modifier.fillMaxSize()) {
                val line = scale * density
                drawRoundRect(AppColors.ink.copy(alpha = .2f), topLeft = Offset(line / 2, line / 2),
                    size = androidx.compose.ui.geometry.Size(size.width - line, size.height - line),
                    cornerRadius = CornerRadius(ClosetDesign.fieldRadius * scale * density),
                    style = Stroke(line, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5 * scale * density, 5 * scale * density))))
            }
        }
    }
}

private fun decodeImage(context: Context, uri: Uri): Bitmap {
    val resolver = context.contentResolver
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    resolver.openInputStream(uri).use { requireNotNull(it); BitmapFactory.decodeStream(it, null, bounds) }
    require(bounds.outWidth >= 2 && bounds.outHeight >= 2)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2400) sample *= 2
    val bitmap = resolver.openInputStream(uri).use { input ->
        requireNotNull(input)
        requireNotNull(BitmapFactory.decodeStream(input, null, BitmapFactory.Options().apply { inSampleSize = sample }))
    }
    val exif = resolver.openInputStream(uri).use { input -> requireNotNull(input); ExifInterface(input) }
    val matrix = Matrix().apply {
        if (exif.isFlipped) postScale(-1f, 1f)
        postRotate(exif.rotationDegrees.toFloat())
    }
    return if (matrix.isIdentity) bitmap else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
}

private suspend fun recognize(bitmap: Bitmap): List<OcrCell> = suspendCancellableCoroutine { continuation ->
    val recognizer = TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
    recognizer.process(InputImage.fromBitmap(bitmap, 0)).addOnSuccessListener { text ->
        val cells = text.textBlocks.flatMap { it.lines }.flatMap { line ->
            line.elements.mapNotNull { element -> element.boundingBox?.let { box ->
                OcrCell(element.text, box.left.toFloat(), box.top.toFloat(), box.width().toFloat(), box.height().toFloat())
            } }
        }
        if (continuation.isActive) continuation.resume(cells)
    }.addOnFailureListener { if (continuation.isActive) continuation.resumeWithException(it) }
        .addOnCompleteListener { recognizer.close() }
}

@Composable
private fun SizeChartCropper(image: Bitmap, onCancel: () -> Unit, onConfirm: (Bitmap) -> Unit) {
    var crop by remember(image) { mutableStateOf(Rect(.06f, .18f, .94f, .82f)) }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }
    fun imageRect(): Rect {
        val scale = min(canvasSize.width.toFloat() / image.width, canvasSize.height.toFloat() / image.height)
        val width = image.width * scale; val height = image.height * scale
        return Rect((canvasSize.width - width) / 2, (canvasSize.height - height) / 2, (canvasSize.width + width) / 2, (canvasSize.height + height) / 2)
    }
    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(AppColors.panel).systemBarsPadding().padding(ClosetDesign.contentInset.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            BasicText("사이즈표 부분만 맞춰주세요", style = CoorditTypography.gmarketBold(18f).copy(color = AppColors.ink))
            BasicText("표 바깥의 상품 사진과 설명을 빼면 OCR 정확도가 좋아져요.", style = CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted))
            Box(Modifier.fillMaxWidth().weight(1f).background(Color.Black.copy(alpha = .92f)).onSizeChanged { canvasSize = it }) {
                Image(image.asImageBitmap(), "자르기 원본", Modifier.fillMaxSize())
                Canvas(Modifier.fillMaxSize().testTag("size-chart-cropper").semantics {
                    contentDescription = "사이즈표 자르기 영역. 모서리를 끌어 크기를 조절하거나 안쪽을 끌어 이동하세요."
                    customActions = listOf(
                        CustomAccessibilityAction("전체 이미지 선택") { crop = Rect(0f, 0f, 1f, 1f); true },
                        CustomAccessibilityAction("영역 축소") { if (crop.width > .28f && crop.height > .28f) crop = Rect(crop.left + .05f, crop.top + .05f, crop.right - .05f, crop.bottom - .05f); true },
                        CustomAccessibilityAction("영역 왼쪽 이동") { val d = min(.05f, crop.left); crop = crop.translate(Offset(-d, 0f)); true },
                        CustomAccessibilityAction("영역 오른쪽 이동") { val d = min(.05f, 1f - crop.right); crop = crop.translate(Offset(d, 0f)); true },
                        CustomAccessibilityAction("영역 위로 이동") { val d = min(.05f, crop.top); crop = crop.translate(Offset(0f, -d)); true },
                        CustomAccessibilityAction("영역 아래로 이동") { val d = min(.05f, 1f - crop.bottom); crop = crop.translate(Offset(0f, d)); true },
                    )
                }.pointerInput(image, canvasSize) {
                    var corner = -1
                    var moving = false
                    detectDragGestures(
                        onDragStart = { point ->
                            val area = imageRect()
                            val rect = Rect(area.left + crop.left * area.width, area.top + crop.top * area.height, area.left + crop.right * area.width, area.top + crop.bottom * area.height)
                            val corners = listOf(rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight)
                            corner = corners.indexOfFirst { (it - point).getDistance() <= 28.dp.toPx() }
                            moving = corner == -1 && rect.contains(point)
                        }
                    ) { change, delta ->
                        val area = imageRect()
                        if (area.width <= 0 || area.height <= 0) return@detectDragGestures
                        val dx = delta.x / area.width; val dy = delta.y / area.height
                        val old = crop
                        crop = if (moving) {
                            val left = (old.left + dx).coerceIn(0f, 1f - old.width)
                            val top = (old.top + dy).coerceIn(0f, 1f - old.height)
                            Rect(left, top, left + old.width, top + old.height)
                        } else if (corner >= 0) Rect(
                            if (corner == 0 || corner == 2) (old.left + dx).coerceIn(0f, old.right - .18f) else old.left,
                            if (corner < 2) (old.top + dy).coerceIn(0f, old.bottom - .18f) else old.top,
                            if (corner == 1 || corner == 3) (old.right + dx).coerceIn(old.left + .18f, 1f) else old.right,
                            if (corner >= 2) (old.bottom + dy).coerceIn(old.top + .18f, 1f) else old.bottom,
                        ) else old
                        change.consume()
                    }
                }) {
                    val area = imageRect()
                    val rect = Rect(area.left + crop.left * area.width, area.top + crop.top * area.height, area.left + crop.right * area.width, area.top + crop.bottom * area.height)
                    val shade = Color.Black.copy(alpha = .54f)
                    drawRect(shade, area.topLeft, androidx.compose.ui.geometry.Size(area.width, rect.top - area.top))
                    drawRect(shade, Offset(area.left, rect.bottom), androidx.compose.ui.geometry.Size(area.width, area.bottom - rect.bottom))
                    drawRect(shade, Offset(area.left, rect.top), androidx.compose.ui.geometry.Size(rect.left - area.left, rect.height))
                    drawRect(shade, Offset(rect.right, rect.top), androidx.compose.ui.geometry.Size(area.right - rect.right, rect.height))
                    drawRect(Color.White, rect.topLeft, rect.size, style = Stroke(2.dp.toPx()))
                    listOf(rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight).forEach { point ->
                        drawCircle(Color.White, 11.dp.toPx(), point)
                        drawCircle(AppColors.ink, 11.dp.toPx(), point, style = Stroke(2.dp.toPx()))
                    }
                }
            }
            CoorditButton("전체 이미지 선택", { crop = Rect(0f, 0f, 1f, 1f) }, secondary = true)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CoorditButton("취소", onCancel, Modifier.weight(1f), secondary = true)
                CoorditButton("표 영역 사용", {
                    val left = (crop.left * image.width).toInt().coerceIn(0, image.width - 2)
                    val top = (crop.top * image.height).toInt().coerceIn(0, image.height - 2)
                    val width = (crop.width * image.width).toInt().coerceIn(2, image.width - left)
                    val height = (crop.height * image.height).toInt().coerceIn(2, image.height - top)
                    onConfirm(Bitmap.createBitmap(image, left, top, width, height))
                }, Modifier.weight(1f))
            }
        }
    }
}
