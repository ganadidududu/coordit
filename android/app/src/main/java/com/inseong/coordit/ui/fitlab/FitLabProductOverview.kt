package com.inseong.coordit.ui.fitlab

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.platform.LocalUriHandler
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

@Composable
internal fun ExampleNotice(s: Float) {
    FitText("예시 체험 · 실제 저장이나 실타래 사용 없이 흐름을 확인해요.", 12f, s)
}

@Composable
internal fun ProductOverview(draft: FitLabDraft, s: Float, edit: () -> Unit) {
    val facts = draft.productFacts?.takeIf { it.appliesTo(draft) }
    val uriHandler = LocalUriHandler.current
    val reading = remember(draft) { FitLabProductReading(draft) }
    var measurementsVisible by rememberSaveable { mutableStateOf(false) }
    var sizeId by rememberSaveable { mutableStateOf<String?>(null) }
    val selected = draft.sizes.firstOrNull { it.id == sizeId } ?: draft.sizes.firstOrNull()
    Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape((8 * s).dp))
        .padding((18 * s).dp).testTag("fitlab-product-overview"), verticalArrangement = Arrangement.spacedBy((14 * s).dp)) {
        Row(Modifier.testTag("fitlab-free-summary"), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((6 * s).dp)) {
            InputMethodGlyph(InputGlyph.CheckCircle, .56f * s)
            FitText("1차 분석 · 무료", 12f, s, true)
        }
        FitText(draft.productName, 19f, s, true)
        FitText(listOf(draft.brand, draft.category.title, draft.mallName).filter { it.isNotBlank() }.joinToString(" · "), 12f, s, color = AppColors.muted)
        Box(Modifier.fillMaxWidth().height(1.dp).background(AppColors.line))
        ReadingParagraph("사이즈 요약 · 치수 기준", reading.conciseSizeSummary, InputGlyph.Ruler, s, "fitlab-summary-size-reading")
        if (facts != null) {
            facts.summary(listOf("material", "lining", "stretch", "thickness", "sheerness"))?.let {
                ReadingParagraph("소재·구조", it, InputGlyph.Garment, s, "fitlab-summary-material")
            }
            facts.summary(listOf("fit", "model"))?.let {
                ReadingParagraph("핏·착용 정보", it, InputGlyph.Person, s, "fitlab-summary-fit")
            }
            facts.summary(listOf("care"))?.let {
                ReadingParagraph("관리", it, InputGlyph.Care, s, "fitlab-summary-care")
            }
            Column(verticalArrangement = Arrangement.spacedBy((4 * s).dp)) {
                FitText("소재·핏·관리 정보는 판매처 제공 내용이에요.", 11f, s, color = AppColors.muted)
                facts.checkedDate?.let { checked ->
                    FitText("확인 " + DateTimeFormatter.ofPattern("yyyy.MM.dd HH:mm").withZone(ZoneId.systemDefault()).format(checked), 11f, s, color = AppColors.muted)
                }
                Pressable(onClick = { uriHandler.openUri(facts.sourceUrl) }, modifier = Modifier.heightIn(min = 44.dp).testTag("fitlab-summary-source")) {
                    FitText("상품 원문 보기", 12f, s)
                }
            }
        } else {
            Box(Modifier.testTag("fitlab-summary-facts-unavailable")) {
                FitText(if (draft.source == FitLabSource.Url) "소재·핏 정보는 확인되지 않았어요." else "소재·핏 정보는 상품 링크에서 확인할 수 있어요.", 12f, s, color = AppColors.muted)
            }
        }
        Box(Modifier.semantics { stateDescription = if (measurementsVisible) "펼쳐짐" else "접힘" }) {
            Secondary(if (measurementsVisible) "상세 실측표 접기  ⌃" else "상세 실측표 펼치기  ⌄", s, "fitlab-toggle-measurements") { measurementsVisible = !measurementsVisible }
        }
        if (measurementsVisible) {
            FitText("사이즈 ${draft.sizes.size}개 · 실측 범위", 14f, s, true)
            reading.measurements.forEach { m -> MeasurementRow(m.key,
                if (m.minimum == m.maximum) "${number(m.minimum)} cm" else "${number(m.minimum)}–${number(m.maximum)} cm", s) }
            if (reading.hasMissingMeasurements) Box(Modifier.testTag("fitlab-summary-missing-measurements")) {
                FitText("일부 치수는 제공되지 않았어요. 확인된 수치만 표시했어요.", 11f, s, color = AppColors.muted)
            }
            FitText("사이즈별로 살펴보기", 14f, s, true)
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy((8 * s).dp)) {
                draft.sizes.forEach { size ->
                    CoorditButton(size.label, { sizeId = size.id }, Modifier.widthIn(min = (60 * s).dp).semantics { this.selected = size.id == selected?.id }.testTag("fitlab-product-size-${size.label}"), secondary = size.id != selected?.id, height = 48 * s, fontSize = 13 * s)
                }
            }
            selected?.let { size ->
                reading.measurements.forEach { m -> size.measurements[m.key]?.takeIf { it.isFinite() && it > 0 }?.let { MeasurementRow(m.key, "${number(it)} cm", s) } }
                draft.sizes.firstOrNull { it.id != size.id }?.let { other ->
                    val differences = reading.measurements.mapNotNull { m ->
                        val current = size.measurements[m.key]?.takeIf { it.isFinite() && it > 0 } ?: return@mapNotNull null
                        val alternative = other.measurements[m.key]?.takeIf { it.isFinite() && it > 0 } ?: return@mapNotNull null
                        "${measurementName(m.key)} ${String.format(java.util.Locale.US, "%+.1f", alternative - current)} cm"
                    }
                    if (differences.isNotEmpty()) Box(Modifier.fillMaxWidth().background(AppColors.closetField, RoundedCornerShape((7 * s).dp)).padding((12 * s).dp).semantics(mergeDescendants = true) {}.testTag("fitlab-summary-size-difference")) {
                        FitText("${size.label} → ${other.label}\n" + differences.joinToString(" · "), 12f, s)
                    }
                }
            }
            FitText("단위 cm · 너비는 단면 기준이에요. 나에게 맞는 핏과 추천 사이즈는 내 옷과 비교해 확인할 수 있어요.", 11f, s, color = AppColors.muted)
        }
    }
    Secondary("상품 정보 수정", s, "fitlab-edit-product", edit)
}

@Composable
private fun ReadingParagraph(title: String, body: String, glyph: InputGlyph, s: Float, tag: String) {
    Column(Modifier.fillMaxWidth().background(AppColors.closetField, RoundedCornerShape((10 * s).dp))
        .border(1.dp, AppColors.ink.copy(alpha = .06f), RoundedCornerShape((10 * s).dp))
        .padding((14 * s).dp).testTag(tag), verticalArrangement = Arrangement.spacedBy((10 * s).dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((7 * s).dp)) {
            InputMethodGlyph(glyph, .64f * s)
            FitText(title, 14f, s, true)
        }
        FitText(body, 13f, s, light = true, lineSpacing = 6f)
    }
}

@Composable
private fun MeasurementRow(key: String, value: String, s: Float) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        FitText(when (key) { "chest_width" -> "가슴 단면"; "waist_width" -> "허리 단면"; "hip_width" -> "엉덩이 단면"; "outseam" -> "아웃심"; else -> measurementName(key) }, 12f, s)
        Spacer(Modifier.weight(1f))
        FitText(value, 12f, s)
    }
}

@Composable
internal fun ComparisonCTA(s: Float, onCompare: () -> Unit) {
    Column(Modifier.fillMaxWidth().testTag("fitlab-comparison-cta"), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((8 * s).dp)) {
        Primary("내 옷과 비교하기", s, "fitlab-review-continue", true, onCompare)
        FitText("실타래 1개가 소모됩니다.", 10f, s, color = AppColors.muted)
    }
}
