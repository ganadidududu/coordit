package com.inseong.coordit.ui.fitlab

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.data.home.HomeCategory
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

@Composable
internal fun ComparisonSelection(state: FitLabState, s: Float, model: FitLabViewModel, register: () -> Unit, recharge: () -> Unit, finishExample: () -> Unit) {
    var cameraNotice by remember { mutableStateOf(false) }
    var discard by remember { mutableStateOf(false) }
    var insufficient by remember { mutableStateOf(false) }
    FitText(state.draft.productName, 13f, s, color = AppColors.muted)
    FitText(if (state.draft.selectedReferenceIds.isNotEmpty()) "비교할 준비가 됐어요" else if (state.references.isEmpty()) "잘 맞는 내 옷과 비교해요" else "어떤 옷과 비교할까요?", 19f, s, true)
    if (state.draft.selectedReferenceIds.isNotEmpty()) ComparisonSubmitPanel(state, s) {
        if (!state.draft.isExample && state.threadBalanceKnown && state.threadBalance <= 0) insufficient = true else model.submit()
    }
    FitText("옷장에 저장한 옷을 고르거나, 아직 등록하지 않은 내 옷으로도 비교할 수 있어요.", 12f, s, color = AppColors.muted)
    run {
        Panel(s, dark = true) {
            SelectionAction("내 옷 링크로 등록", "등록 후 자동 선택 · 옷장에 저장", InputGlyph.Link, s, "fitlab-manage-references", !state.busy, register)
            SelectionAction("카메라로 등록", "준비 중 · 지금은 링크나 사이즈표 이용", InputGlyph.Camera, s, "fitlab-camera-comparison", !state.busy) { cameraNotice = true }
        }
    }
    FitText(if (state.draft.isExample) "실제 이용 시 등록한 내 옷과 보유 사이즈는 옷장에 자동 저장돼요. 다음에는 옷장에서 바로 골라 비교할 수 있어요. 이번 예시에서는 저장하지 않아요." else "등록한 내 옷과 보유 사이즈는 옷장에 자동 저장돼요. 다음에는 옷장에서 바로 골라 비교할 수 있어요.", 11f, s, color = AppColors.muted)
    if (state.references.isEmpty() && !state.busy) {
        Panel(s) {
            FitText("기준 옷이 아직 없나요?", 15f, s, true)
            FitText("기준 옷은 평소 잘 맞는 내 옷이에요. 구매할 새 상품이 아니라, 이미 가진 옷의 링크로 등록하고 실제 보유 사이즈를 골라주세요.", 12f, s)
            FitText("링크가 없으면 옷장의 ‘사이즈표 사진 넣기’를 이용할 수 있어요. 카메라로 직접 재는 기능은 준비 중이에요.", 11f, s, color = AppColors.muted)
        }
    }
    Panel(s, dark = true) {
        SelectionAction("옷장에서 골라 비교", "저장된 내 옷 사용 · 다시 등록할 필요 없어요", InputGlyph.Garment, s, "fitlab-choose-closet", true, model::showReferencePicker)
    }
    if (state.busy) FitText("옷장을 불러오는 중이에요", 12f, s)
    if (state.draft.selectedReferenceIds.isEmpty()) ComparisonSubmitPanel(state, s) {
        if (!state.draft.isExample && state.threadBalanceKnown && state.threadBalance <= 0) insufficient = true else model.submit()
    }
    state.error?.let { Error(it, s); Secondary("다시 불러오기", s, "fitlab-reload-references", model::loadReferences) }
    Secondary("다른 상품 넣기", s, "fitlab-discard-submission") { discard = true }
    if (cameraNotice) CameraComingSoon { cameraNotice = false }
    if (discard) CoorditConfirmationDialog("새 상품을 등록할까요?", "현재 입력한 상품 정보, 기준 의류 선택, 아직 저장하지 않은 분석 결과는 초기화돼요. 이미 저장된 분석 기록은 그대로 남아요.", "계속 입력", "새 상품 등록", { discard = false }, { discard = false; model.restart(); if (state.draft.isExample) finishExample() }, "fitlab-discard-confirm", destructive = true)
    if (insufficient) CoorditConfirmationDialog("실타래가 부족해요", "상세 비교 리포트를 보려면 실타래 1개가 필요해요. 광고를 보고 무료로 충전할 수 있어요.", "나중에", "실타래 충전하기", { insufficient = false }, { insufficient = false; recharge() }, "fitlab-recharge-confirm")
}

@Composable
private fun ComparisonSubmitPanel(state: FitLabState, s: Float, submit: () -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy((14 * s).dp)) {
        if (state.draft.selectedReferenceIds.isNotEmpty()) Box(Modifier.testTag("fitlab-selected-reference-summary")) {
            FitText("선택한 기준 옷 ${state.draft.selectedReferenceIds.size}벌 · " + state.references.filter { it.id in state.draft.selectedReferenceIds }.joinToString(", ") { it.nickname ?: "기준 옷" }, 12f, s)
        }
        Box(Modifier.testTag("fitlab-comparison-cost")) {
            FitText("내 옷과 비교하고 상세 리포트를 만들 때 실타래 1개를 사용해요. 링크 등록과 1차 분석은 무료예요.", 12f, s, color = AppColors.muted)
        }
        Primary("비교하기 · 실타래 1개", s, "fitlab-submit", state.draft.selectedReferenceIds.isNotEmpty() && !state.busy, submit)
    }
}

@Composable
private fun SelectionAction(title: String, subtitle: String, glyph: InputGlyph, s: Float, tag: String, enabled: Boolean, action: () -> Unit) {
    Pressable(action, Modifier.fillMaxWidth().testTag(tag), enabled = enabled, cornerRadius = 7 * s) {
        Row(Modifier.fillMaxWidth().heightIn(min = (64 * s).dp).background(AppColors.panel, RoundedCornerShape((7 * s).dp)).padding((14 * s).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((12 * s).dp)) {
            InputMethodGlyph(glyph, s)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((5 * s).dp)) {
                FitText(title, 14f, s, true)
                FitText(subtitle, 11f, s, color = AppColors.muted)
            }
        }
    }
}

@Composable
internal fun ReferencePicker(state: FitLabState, model: FitLabViewModel, register: () -> Unit) {
    var selected by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(state.draft.selectedReferenceIds.toList()) }
    val available = state.references.filter { it.isActive && referenceIsCompatible(it.category, state.draft.category) }
    val valid = selected.intersect(available.map { it.id }.toSet())
    Dialog(onDismissRequest = model::dismissReferencePicker, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(.94f).background(AppColors.panel, RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)).testTag("fitlab-reference-picker")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 18.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { FitText("비교할 내 옷 고르기", 20f, 1f, true) }
                Pressable(model::dismissReferencePicker, Modifier.size(48.dp).testTag("fitlab-reference-picker-close")
                    .semantics { contentDescription = "옷 선택 취소" }) { InputMethodGlyph(InputGlyph.CloseCircleFilled, 1f) }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(22.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                FitText("평소 잘 맞는 옷을 골라주세요. 여러 벌을 선택할 수도 있어요.", 13f, 1f)
                when {
                    state.busy -> FitText("옷장을 불러오는 중이에요", 14f, 1f)
                    available.isEmpty() -> {
                        Box(Modifier.padding(vertical = 24.dp).testTag("fitlab-reference-picker-empty")) { FitText("비교할 옷이 아직 없어요. 이 상품과 비슷한 종류의 옷을 먼저 등록해주세요.", 14f, 1f) }
                        state.error?.let { Error(it, 1f); Secondary("다시 불러오기", 1f, "fitlab-reference-picker-retry", model::loadReferences) }
                        Primary("내 옷 링크로 등록", 1f, "fitlab-reference-picker-register", true) { model.dismissReferencePicker(); register() }
                    }
                    else -> available.forEach { reference ->
                        val chosen = reference.id in selected
                        Pressable({ selected = if (chosen) selected - reference.id else selected + reference.id }, Modifier.fillMaxWidth().semantics { this.selected = chosen }.testTag("fitlab-reference-${reference.id}"), cornerRadius = 12f) {
                            Row(Modifier.fillMaxWidth().heightIn(min = 72.dp).background(if (chosen) AppColors.placeholder else AppColors.closetField, RoundedCornerShape(12.dp)).padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                InputMethodGlyph(if (chosen) InputGlyph.CheckCircleFilled else InputGlyph.Circle, 1f)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                    FitText(reference.nickname ?: "기준 옷", 14f, 1f, true)
                                    FitText("${HomeCategory.entries.firstOrNull { it.wireName == reference.category }?.title ?: "기준 의류"} · ${reference.fitType}", 12f, 1f)
                                }
                            }
                        }
                    }
                }
            }
            Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Primary("선택 완료 · ${valid.size}벌", 1f, "fitlab-reference-picker-done", valid.isNotEmpty() && !state.busy) { model.confirmReferences(valid) }
                FitText("옷을 고르는 단계에서는 실타래를 사용하지 않아요.", 11f, 1f, color = AppColors.muted)
            }
        }
    }
}
