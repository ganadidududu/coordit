package com.inseong.coordit.ui.fitlab

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.inseong.coordit.data.fitlab.*
import com.inseong.coordit.R
import com.inseong.coordit.data.fitlab.FitLabScreen as FitLabRoute
import com.inseong.coordit.data.home.HomeCategory
import com.inseong.coordit.ui.closet.ClosetMannequin
import com.inseong.coordit.ui.closet.ClosetPhotoInput
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*
import java.util.Locale
import java.util.UUID
import java.util.Date

private object FitLabDesign {
    const val canvas = 402f
    const val contentTop = 115f
    const val inset = 22f
    const val panelRadius = 8f
    const val fieldRadius = 7f
    const val gap = 14f
    val field = AppColors.closetField
    val empty = AppColors.placeholder
    val ink = AppColors.ink
}

@Composable
fun FitLabScreen(model: FitLabViewModel, onHome: () -> Unit, onCloset: () -> Unit, onProfile: () -> Unit, onRegisterReference: () -> Unit = onCloset, onExampleFinished: () -> Unit = {}, onRecharge: () -> Unit = onProfile, onStartExample: () -> Unit = { model.beginExample() }) {
    val state by model.state.collectAsStateWithLifecycle()
    val contentScroll = rememberScrollState()
    LaunchedEffect(state.screen) { contentScroll.scrollTo(0) }
    var guide by remember { mutableStateOf<com.inseong.coordit.ui.guidance.UsageGuide?>(null) }
    if (state.requiresThreads) CoorditConfirmationDialog("실타래가 부족해요", "상세 비교 리포트를 보려면 실타래 1개가 필요해요. 광고를 보고 무료로 충전할 수 있어요.", "나중에", "실타래 충전하기", model::dismissThreadNotice, { model.dismissThreadNotice(); onRecharge() }, "fitlab-server-recharge")
    var pendingLeave by remember { mutableStateOf<(() -> Unit)?>(null) }
    fun leave(action: () -> Unit) { if (state.draft.isExample) pendingLeave = action else action() }
    fun back() {
        if (state.screen == FitLabRoute.Loading && state.busy) onHome()
        else if (!state.busy) {
            if (state.draft.isExample && state.screen != FitLabRoute.References) leave(onHome)
            else if (!model.back()) onHome()
        }
    }
    pendingLeave?.let { action -> CoorditConfirmationDialog("처음이라면 끝까지 따라 해보는 걸 추천해요", "예시로 등록과 비교 흐름을 익힐 수 있어요. 나중에 사용법에서 다시 시작할 수도 있어요.", "계속 따라하기", "이번에는 건너뛰기", { pendingLeave = null }, { pendingLeave = null; model.finishExample(); onExampleFinished(); action() }, "fitlab-example-skip") }
    guide?.let { value -> com.inseong.coordit.ui.guidance.UsageGuideSheet(value, { guide = null }, { guide = null; onStartExample() }) }
    if (state.referencePickerVisible) ReferencePicker(state, model, onRegisterReference)

    BackHandler { back() }
    BoxWithConstraints(Modifier.fillMaxSize().testTag("fitlab-${state.screen.name.lowercase()}")) {
        val s = maxWidth.value / FitLabDesign.canvas
        SharedAppBackground(s)
        Column(Modifier.fillMaxSize().imePadding().padding(top = (FitLabDesign.contentTop * s).dp, bottom = (104 * s).dp)) {
            FeatureTitleBar(if (state.screen == FitLabRoute.HistoryDetail) "FIT DETAIL" else "FIT LAB", s, ::back,
                { guide = if (state.screen == FitLabRoute.References) com.inseong.coordit.ui.guidance.UsageGuide.References else com.inseong.coordit.ui.guidance.UsageGuide.FitLab }, "fitlab-back", "fitlab-tutorial-restart")
            Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(contentScroll).testTag("fitlab-scroll")
                .padding(horizontal = ((if (state.screen == FitLabRoute.Result || state.screen == FitLabRoute.HistoryDetail) 24f else FitLabDesign.inset) * s).dp)
                .padding(top = (22 * s).dp, bottom = (24 * s).dp), verticalArrangement = Arrangement.spacedBy((FitLabDesign.gap * s).dp)) {
                if (state.draft.isExample) {
                    val hint = when (state.screen) {
                        FitLabRoute.Url -> "상품 정보 불러오기" to "다음을 누르면 링크의 상품과 사이즈 정보를 무료로 정리해요."
                        FitLabRoute.Review -> "무료 분석 확인하고 비교하기" to "아래 리포트를 읽고 ‘내 옷과 비교하기’를 눌러주세요."
                        FitLabRoute.References -> if (state.references.isEmpty()) "먼저 기준 옷을 등록해요" to "‘내 옷 링크로 등록’에서 잘 맞는 보유 의류를 등록해볼게요. 실제 저장은 하지 않아요." else if (state.draft.selectedReferenceIds.isEmpty()) "등록한 기준 옷 선택하기" to "‘옷장에서 골라 비교’를 누르고, 방금 등록한 예시 옷을 선택해주세요." else "핏 분석 시작하기" to "선택한 내 옷과 상품의 사이즈를 비교해요. 예시 체험에서는 실타래를 사용하지 않아요."
                        FitLabRoute.Result -> "사이즈별 핏 비교하기" to "추천 사이즈와 핏 점수를 확인합니다. 아래 사이즈를 누르면 해당 사이즈의 점수와 부위별 차이를 비교할 수 있습니다. 예시는 체험 마치기로 끝내요."
                        else -> "읽지 못한 값 보완하기" to "누락되거나 잘못 읽힌 값만 수정해주세요. 정상적으로 읽힌 사이즈표는 바로 넘어가요."
                    }
                    com.inseong.coordit.ui.guidance.PracticeHint(when (state.screen) { FitLabRoute.Review -> "2/3 · 무료 리포트"; FitLabRoute.References, FitLabRoute.Result -> "3/3 · 내 옷과 비교"; else -> "1/3 · 상품 링크" }, hint.first, hint.second, { leave {} }, s)
                }
                when (state.screen) {
                    FitLabRoute.Sources -> Sources(state, s, model::chooseSource, model::openHistory)
                    FitLabRoute.Manual -> DraftEditor(state, s, model, "", "")
                    FitLabRoute.Url -> UrlEditor(state, s, model)
                    FitLabRoute.Ocr -> OcrEditor(state, s, model)
                    FitLabRoute.Review -> {
                        ProductOverview(state.draft, s, model::editProduct)
                        ComparisonCTA(s, model::continueToReferences)
                    }
                    FitLabRoute.References -> ComparisonSelection(state, s, model, onRegisterReference, onRecharge, onExampleFinished)
                    FitLabRoute.Loading -> Loading(state, s, model::submit)
                    FitLabRoute.Result -> Result(state, s, { model.restart(); if (state.draft.isExample) onExampleFinished() }, model::saveHistory, model::retryReport)
                    FitLabRoute.HistoryDetail -> HistoryDetail(state, s, model::deleteHistory)
                }
            }
        }
        CoorditHeader(s, { leave(onProfile) }, Modifier.align(Alignment.TopCenter).padding(top = (55 * s).dp))
        CoorditBottomNavigation(CoorditTab.FitLab, s, { tab -> if (!state.busy || state.screen == FitLabRoute.Loading) when (tab) { CoorditTab.Home -> leave(onHome); CoorditTab.FitLab -> Unit; CoorditTab.Closet -> leave(onCloset) } }, Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun Sources(state: FitLabState, s: Float, choose: (FitLabSource) -> Unit, openHistory: (FitLabHistorySnapshot) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy((5*s).dp)) {
        FitText("어떤 옷이 궁금하세요?",18f,s,true,Color.Black)
        FitText("상품 링크나 사이즈표 사진을 넣어주세요.",12f,s,color=Color.Black.copy(alpha=.64f),light=true)
    }
    Column(Modifier.fillMaxWidth().background(Brush.linearGradient(listOf(Color(90,104,164),Color(21,35,98),FitLabDesign.ink)),RoundedCornerShape((8*s).dp)).padding((8*s).dp),verticalArrangement=Arrangement.spacedBy((8*s).dp)) {
        SourceCard("링크로 불러오기","추천 · 상품과 사이즈를 한 번에",FitLabSource.Url,s,choose)
        SourceCard("사이즈표 사진 넣기","사이즈표 캡처에서 치수 읽기",FitLabSource.Ocr,s,choose)
    }
    var allHistory by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(false) }
    Panel(s) {
        FitText("최근 핏 분석",15f,s,true,Color.Black)
        if (state.history.size > 3) Secondary(if (allHistory) "최근 3개만 보기" else "전체 ${state.history.size}개 보기", s, "fitlab-history-toggle") { allHistory = !allHistory }
        if (state.history.isEmpty()) Column(Modifier.fillMaxWidth().padding(vertical=(20*s).dp),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.spacedBy((8*s).dp)) {
            FitText("◷",22f,s,color=FitLabDesign.ink.copy(alpha=.5f)); FitText("저장한 핏 분석이 아직 없어요",13f,s,color=Color.Black.copy(alpha=.7f)); FitText("분석 리포트에서 히스토리 저장을 누르면 여기에 표시돼요.",11f,s,color=Color.Black.copy(alpha=.55f),light=true)
        } else (if (allHistory) state.history else state.history.take(3)).forEach { snapshot ->
            Pressable({ openHistory(snapshot) }, Modifier.fillMaxWidth().testTag("fitlab-history-${snapshot.analysisId}"), cornerRadius = 7 * s) {
                Row(Modifier.fillMaxWidth().background(FitLabDesign.field, RoundedCornerShape((7*s).dp)).padding((12*s).dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((4*s).dp)) {
                        FitText(snapshot.productName, 13f, s, true, Color.Black)
                        FitText("${snapshot.recommendation.recommendedSize} · ${score(snapshot.recommendation.fitScore)}점 · ${sourceLabel(snapshot.source)}", 10f, s, color = Color.Black.copy(alpha=.62f))
                        FitText(java.text.DateFormat.getDateTimeInstance(java.text.DateFormat.MEDIUM, java.text.DateFormat.SHORT, Locale.KOREA).format(Date(snapshot.savedAt)), 9f, s, color = Color.Black.copy(alpha=.5f), light = true)
                    }
                    FitText("›", 18f, s, true, Color.Black.copy(alpha=.48f))
                }
            }
        }
    }
    state.error?.let { Error(it,s) }
}

@Composable private fun SourceCard(title:String,subtitle:String,source:FitLabSource,s:Float,choose:(FitLabSource)->Unit) {
    Pressable({choose(source)},Modifier.fillMaxWidth().testTag("fitlab-source-${source.name.lowercase()}"),cornerRadius=7*s) {
        Row(Modifier.fillMaxWidth().heightIn(min=(60*s).dp).background(Brush.linearGradient(listOf(Color(250,251,254),Color(225,230,243))),RoundedCornerShape((7*s).dp)).padding(horizontal=(12*s).dp,vertical=(7*s).dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((11*s).dp)) {
            Box(Modifier.size((36*s).dp).background(FitLabDesign.field,RoundedCornerShape((7*s).dp)),contentAlignment=Alignment.Center) { SourceIcon(source,s) }
            Column(Modifier.weight(1f),verticalArrangement=Arrangement.spacedBy((3*s).dp)){FitText(title,14f,s,true,Color.Black);FitText(subtitle,11f,s,color=Color.Black.copy(alpha=.58f),light=true)}
        }
    }
}

@Composable private fun SourceIcon(source: FitLabSource, s: Float) {
    InputMethodGlyph(when (source) { FitLabSource.Url -> InputGlyph.Link; FitLabSource.Ocr -> InputGlyph.SizeChart; FitLabSource.Manual -> InputGlyph.Ruler }, s * .76f)
}

@Composable
private fun DraftEditor(state: FitLabState,s:Float,model:FitLabViewModel,title:String,subtitle:String,showConfirm:Boolean=true) {
    val focus = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    var pendingCategory by remember { mutableStateOf<HomeCategory?>(null) }
    val hasDiscardableData = state.draft.productName.isNotBlank() || state.draft.brand.isNotBlank() ||
        state.draft.selectedReferenceIds.isNotEmpty() || state.draft.sizes.any { it.label.isNotBlank() || it.measurements.isNotEmpty() }
    fun requestCategory(category: HomeCategory) {
        if (category == state.draft.category) return
        if (hasDiscardableData) pendingCategory = category else model.setCategory(category)
    }
    if (title.isNotBlank()) Column(verticalArrangement = Arrangement.spacedBy((4*s).dp)) {
        FitText(title,19f,s,true,Color.Black)
        FitText(subtitle,12f,s,color=Color.Black.copy(alpha=.65f),light=true)
    }
    Panel(s) {
        FitText("1. 의류 구분",14f,s,true,Color.Black)
        Segment(state.draft.upper,s){upper->requestCategory(if(upper)HomeCategory.Tshirt else HomeCategory.Pants)}
    }
    Panel(s) {
        FitText("2. 카테고리와 상품",14f,s,true,Color.Black)
        CategoryPicker(state.draft.category, s, ::requestCategory)
        Row(Modifier.fillMaxWidth()) {
            FitText("현재 카테고리 ${state.draft.category.title}",9f,s,color=Color.Black.copy(alpha=.5f),light=true)
            Spacer(Modifier.weight(1f))
            FitText("선택한 기준 옷 ${state.draft.selectedReferenceIds.size}개",9f,s,color=Color.Black.copy(alpha=.5f),light=true)
        }
        Field(state.draft.productName,{v->model.edit{it.copy(productName=v)}},"상품명","fitlab-product-name",s)
        Field(state.draft.brand,{v->model.edit{it.copy(brand=v)}},"브랜드 (선택)","fitlab-brand",s)
    }
    Panel(s) {
        FitText("3. 사이즈표",14f,s,true,Color.Black)
        FitText("모든 수치는 옷을 평평하게 놓고 잰 단면(cm)이에요. 가능한 경우에는 둘레가 아니라 단면 너비를 입력해 주세요.",10f,s,color=Color.Black.copy(alpha=.58f),light=true)
        state.draft.sizes.forEachIndexed { index,row -> key(row.id) { SizeEditor(row,index,state.draft.category,s,model) } }
        Secondary("+ 사이즈 행 추가",s,"fitlab-add-size") { model.edit { it.copy(sizes=it.sizes+FitLabSizeDraft(UUID.randomUUID().toString())) } }
    }
    state.error?.let { Error(it,s) }
    if(showConfirm) Primary("확인하고 1차 분석 보기",s,"fitlab-confirm-draft",!state.busy){focus.clearFocus(force = true); keyboard?.hide(); model.confirmDraft()}
    pendingCategory?.let { category ->
        Dialog(onDismissRequest = { pendingCategory = null }) {
            Panel(s) {
                FitText("입력값을 변경할까요?", 18f, s, true, Color.Black)
                FitText("호환되지 않는 측정값과 선택한 기준 옷이 삭제돼요.", 11f, s, color = Color.Black.copy(alpha = .66f))
                Secondary("취소", s, "fitlab-category-cancel") { pendingCategory = null }
                CoorditButton("변경", { model.setCategory(category); pendingCategory = null }, Modifier.testTag("fitlab-category-confirm"), danger = true)
            }
        }
    }
}

@Composable private fun UrlEditor(state:FitLabState,s:Float,model:FitLabViewModel){
    Panel(s) {
        FitText("상품 링크를 넣어주세요",18f,s,true,Color.Black)
        FitText("링크의 상품과 사이즈 정보를 무료로 정리해요.",12f,s,color=Color.Black.copy(alpha=.65f),light=true)
        if (state.draft.isExample) ExampleNotice(s)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((8*s).dp)) {
            Box(Modifier.weight(1f)) { Field(state.draft.productUrl,{v->model.edit{it.copy(productUrl=v)}},"상품 링크 입력","fitlab-product-url",s, enabled = !state.busy, url = true) }
            Box(Modifier.width((82*s).dp)) { LinkPasteButton(s, "fitlab-url-paste", !state.busy) { value -> model.edit { it.copy(productUrl = value) } } }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { FitText("링크에서 옷 종류 자동으로 찾기",12f,s) }
            SettingsToggle(state.draft.automaticCategory, { value -> model.edit { it.copy(automaticCategory = value) } }, "링크에서 옷 종류 자동으로 찾기", s, Modifier.testTag("fitlab-url-automatic-category"))
        }
        if (!state.draft.automaticCategory) {
            Segment(state.draft.upper,s){model.setCategory(if(it)HomeCategory.Tshirt else HomeCategory.Pants)}
            CategoryRow(state.draft.category,s){model.setCategory(it)}
        }
        state.error?.let{Error(it,s)}
        Primary(if(state.busy)"불러오는 중" else "다음",s,"fitlab-url-import",state.draft.productUrl.isNotBlank()&&!state.busy){model.prefill()}
        if (state.error != null) {
            Secondary("사진 OCR로 전환", s, "fitlab-source-ocr") { model.chooseSource(FitLabSource.Ocr) }
            Secondary("직접 입력", s, "fitlab-source-manual") { model.chooseSource(FitLabSource.Manual) }
        }
    }
}

@Composable private fun OcrEditor(state:FitLabState,s:Float,model:FitLabViewModel){
    if(state.draft.sizes.any{it.measurements.isNotEmpty()}) DraftEditor(state,s,model,"OCR 결과 · 저장 전 확인 필요","인식된 값을 확인하고 필요한 값을 수정해 주세요.")
    else {
        FitText("사이즈표 사진 넣기",19f,s,true,Color.Black);FitText("사진은 기기 안에서만 ML Kit로 읽으며\n서버에 업로드하지 않아요.",12f,s,color=Color.Black.copy(alpha=.66f),light=true)
        Panel(s) {
            FitText("옷 종류", 14f, s, true)
            Segment(state.draft.upper, s) { model.setCategory(if (it) HomeCategory.Tshirt else HomeCategory.Pants) }
            CategoryRow(state.draft.category, s, model::setCategory)
        }
        ClosetPhotoInput(state.draft.upper,onRows={rows->model.setRows(rows.map{FitLabSizeDraft(UUID.randomUUID().toString(),it.label,it.measurements)})},onGarment={},enabled=!state.busy,scale=s)
        Secondary("직접 입력으로 전환",s,"fitlab-ocr-manual"){model.chooseSource(FitLabSource.Manual)}
        state.error?.let{Error(it,s)}
    }
}

@Composable
private fun SizeEditor(row: FitLabSizeDraft, index: Int, category: HomeCategory, s: Float, model: FitLabViewModel) {
    Column(
        Modifier.fillMaxWidth().background(FitLabDesign.empty.copy(alpha = .46f), RoundedCornerShape((7 * s).dp)).padding((12 * s).dp),
        verticalArrangement = Arrangement.spacedBy((9 * s).dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            FitText("사이즈 ${index + 1}", 15f, s, true, Color.Black)
            Spacer(Modifier.weight(1f))
            if (index > 0) Pressable({ model.edit { it.copy(sizes = it.sizes.filterNot { size -> size.id == row.id }) } }, Modifier.testTag("fitlab-remove-size-$index")) {
                FitText("삭제", 10f, s, color = AppColors.danger)
            }
        }
        Field(row.label, { value -> model.edit { draft -> draft.copy(sizes = draft.sizes.map { if (it.id == row.id) it.copy(label = value) else it }) } }, "사이즈명 (예: M)", "fitlab-size-label-$index", s)
        val keys = if (category == HomeCategory.Skirt) listOf("waist_width", "hip_width", if (row.measurements.containsKey("outseam") && !row.measurements.containsKey("total_length")) "outseam" else "total_length") else measurementKeys(category)
        keys.map { it to measurementName(it) }.forEach { (key, label) ->
            MeasureField("$label 단면", row.measurements[key], "fitlab-size-$index-$key", s, Modifier.fillMaxWidth()) { value ->
                model.edit { draft ->
                    draft.copy(sizes = draft.sizes.map {
                        if (it.id == row.id) it.copy(measurements = if (value == null) it.measurements - key else it.measurements + (key to value)) else it
                    })
                }
            }
        }
    }
}

@Composable private fun Loading(state:FitLabState,s:Float,retry:()->Unit){Panel(s){FitText(if(state.error==null)"핏 분석을 만들고 있어요" else "핏 분석을 완료하지 못했어요",20f,s,true,Color.Black);FitText(stepText(state.step),12f,s,color=Color.Black.copy(alpha=.66f));Box(Modifier.fillMaxWidth().height((6*s).dp).background(FitLabDesign.empty,CircleShape)){Box(Modifier.fillMaxWidth(progress(state.step)).fillMaxHeight().background(FitLabDesign.ink,CircleShape))};state.error?.let{Error(it,s);Primary("완료된 단계부터 다시 시도",s,"fitlab-retry",!state.busy,retry)}}}

@Composable
private fun ResultComparison(result: FitLabRecommendation, report: FitLabReportResponse?, upper: Boolean, s: Float, basis: String = "현재 베스트 스코어 기준") {
    var selected by remember(result.fitAnalysisResultId) { mutableStateOf(result.recommendedSize) }
    val selection = selectFitLabScore(result, report, selected)
    val differences = selection.comparisons.associate { it.measurement to it.diff }
        .ifEmpty { if (selection.isRecommended) result.diff else emptyMap() }
    ScoreCard(
        if (selection.isRecommended) basis else "선택 사이즈 비교 기준",
        result.copy(recommendedSize = selected, fitScore = selection.fitScore), s,
        selected = !selection.isRecommended,
    )
    ClosetMannequin(upper, differences.mapValues { it.value as Double? }, s)
    ScoreBars((report?.chartData?.sizeScoreRanking.orEmpty() + result.allSizeScores).distinctBy { it.sizeLabel }, result.recommendedSize, s, selected) { selected = it }
    Column(Modifier.fillMaxWidth().testTag("fitlab-comparison-basis"), verticalArrangement = Arrangement.spacedBy((6 * s).dp)) {
        FitText("비교 중 $selected · 추천 ${result.recommendedSize}", 12f, s, true, FitLabDesign.ink)
        FitText("사이즈를 선택하면 점수와 실측 비교가 함께 바뀌어요.", 10f, s, color = Color.Black.copy(alpha = .55f))
        if (!selection.isRecommended && selection.measurementScores.isEmpty()) {
            FitText("이 사이즈의 세부 점수는 저장되어 있지 않아요. 상품 사이즈표와 함께 확인해 주세요.", 11f, s, color = FitLabDesign.ink)
        }
    }
    FitPointScores(selection.fitPointScores, s)
    MeasurementScores(selection.measurementScores, s)
    if (!selection.isRecommended && selection.comparisons.isEmpty()) {
        FitText("부위별 실측도 없어 총점만 비교할 수 있어요.", 11f, s, color = FitLabDesign.ink)
    } else DifferenceChart(emptyList(), selection.comparisons, differences, s)
}

@Composable
private fun Result(state: FitLabState, s: Float, restart: () -> Unit, saveHistory: () -> Unit, retryReport: () -> Unit) {
    val result = state.recommendation ?: return
    if (state.draft.isExample) ExampleNotice(s)
    ResultComparison(result, state.report, state.draft.upper, s)
    ReportDetails(state.report?.report, state.report?.chartData, state.reportError, s, result.recommendedSize)
    if (state.reportError != null) Primary(if (state.busy) "리포트 다시 만드는 중..." else "상세 리포트 다시 만들기", s, "fitlab-retry-report", !state.busy, retryReport)
    state.error?.let { Error(it, s) }
    if (state.report != null && !state.draft.isExample) Primary(if (state.historySaved) "히스토리에 저장됨" else if (state.busy) "저장 중..." else "히스토리에 추가", s, "fitlab-save-history", !state.busy && !state.historySaved, saveHistory)
    else if (!state.draft.isExample) FitText("기준 옷 비교를 완성한 뒤 히스토리에 저장할 수 있어요.", 10f, s, color = Color.Black.copy(alpha=.62f))
    Secondary(if (state.draft.isExample) "체험 마치고 내 상품 분석하기" else "확인하기", s, "fitlab-restart", restart)
    FitText(
        if (state.historySaved) "저장한 리포트는 핏랩과 홈의 최근 히스토리에서 다시 확인할 수 있어요." else "확인하기를 누르면 이 리포트는 저장되지 않고 핏랩으로 돌아가요.",
        10f,
        s,
        color = Color.Black.copy(alpha = .62f),
    )
}

@Composable
private fun HistoryDetail(state: FitLabState, s: Float, delete: () -> Unit) {
    val snapshot = state.selectedHistory ?: return
    val result = snapshot.recommendation
    Panel(s) {
        FitText(snapshot.productName, 19f, s, true, Color.Black)
        FitText("${HomeCategory.entries.firstOrNull { it.wireName == snapshot.category }?.title ?: "의류"} · ${result.recommendedSize} · ${java.text.DateFormat.getDateTimeInstance(java.text.DateFormat.MEDIUM, java.text.DateFormat.SHORT, Locale.KOREA).format(Date(snapshot.savedAt))}", 11f, s, color = Color.Black.copy(alpha = .62f))
        FitText("입력: ${sourceLabel(snapshot.source)} · 기준 옷 ${snapshot.referenceCount}개", 10f, s, color = Color.Black.copy(alpha = .55f), light = true)
    }
    ResultComparison(result, snapshot.report, snapshot.upper, s, "과거 기준치 기준")
    ReportDetails(snapshot.report.report, snapshot.report.chartData, null, s, result.recommendedSize)
    state.error?.let { Error(it, s) }
    LightAction(if (state.busy) "삭제 중..." else "이 히스토리 삭제", s, "fitlab-delete-history", !state.busy, delete)
}

@Composable
private fun ScoreCard(
    basis: String,
    result: FitLabRecommendation,
    s: Float,
    subtitle: String? = null,
    selected: Boolean = false,
) {
    Panel(s) {
        FitText(basis, 10f, s, color = Color.Black.copy(alpha = .64f))
        CoorditText("FIT SCORE", CoorditTypography.climate2019(19 * s).copy(color = Color.Black, letterSpacing = (.7f * s).sp))
        subtitle?.let { FitText(it, 10f, s, color = Color.Black.copy(alpha = .55f)) }
        Row(verticalAlignment = Alignment.Bottom) {
            Column(verticalArrangement = Arrangement.spacedBy((2 * s).dp)) {
                FitText(if (selected) "선택한 사이즈" else "추천 사이즈", 9f, s, color = Color.Black)
                Box(Modifier.semantics(mergeDescendants = true) {}.testTag("fitlab-selected-size")) { FitText(result.recommendedSize, 20f, s, true, Color.Black) }
            }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy((2 * s).dp)) {
                FitText("총점", 9f, s, color = Color.Black)
                Box(Modifier.semantics(mergeDescendants = true) {}.testTag("fitlab-selected-score")) { FitText("${score(result.fitScore)}점", 20f, s, true, Color.Black) }
            }
        }
    }
}

@Composable
private fun ScoreBars(rows: List<FitLabSizeScore>, recommended: String, s: Float, selected: String, select: (String) -> Unit) {
    if (rows.isEmpty()) return
    Panel(s) {
        CoorditText("SIZE SCORE COMPARISON", CoorditTypography.mona12(16 * s).copy(color = Color.Black))
        FitText("모든 사이즈를 같은 기준으로 비교한 결과예요.", 10f, s, color = Color.Black.copy(alpha = .55f))
        rows.forEach { row ->
            val active = row.sizeLabel == selected
            Pressable(
                onClick = { select(row.sizeLabel) },
                modifier = Modifier.fillMaxWidth().testTag("fitlab-score-${row.sizeLabel}"),
                cornerRadius = 7 * s,
            ) {
                Row(Modifier.fillMaxWidth().heightIn(min = (44 * s).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((8 * s).dp)) {
                    Box(Modifier.width((58 * s).dp).height((28 * s).dp).background(if (active) FitLabDesign.ink else FitLabDesign.field, RoundedCornerShape((6 * s).dp)).padding(horizontal = (7 * s).dp), contentAlignment = Alignment.CenterStart) {
                        FitText(row.sizeLabel, 12f, s, true, if (active) Color.White else FitLabDesign.ink)
                    }
                    Box(Modifier.weight(1f).height((11 * s).dp).background(FitLabDesign.field, CircleShape)) {
                        Box(
                            Modifier.fillMaxWidth((row.fitScore / 100.0).coerceIn(0.0, 1.0).toFloat())
                                .fillMaxHeight()
                                .background(if (active) FitLabDesign.ink else AppColors.blue.copy(alpha = .42f), CircleShape),
                        )
                    }
                    FitText(score(row.fitScore), 11f, s, true, Color.Black)
                    if (row.sizeLabel == recommended) FitText("추천", 8f, s, true, AppColors.green)
                }
            }
        }
    }
}

@Composable
private fun FitPointScores(rows: List<FitLabFitPointScore>, s: Float) {
    if (rows.isEmpty()) return
    Column(Modifier.fillMaxWidth().testTag("fitlab-fit-profile")) {
        Panel(s) {
            CoorditText("FIT PROFILE BREAKDOWN", CoorditTypography.mona12(16 * s).copy(color = Color.Black))
            FitText("기준 옷과의 실측 차이를 착용 관점으로 나눈 점수예요.", 10f, s, color = Color.Black.copy(alpha = .55f))
            rows.forEach { row ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = (34 * s).dp).testTag("fitlab-fit-point-${row.key}"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy((9 * s).dp),
                ) {
                    Box(Modifier.width((58 * s).dp)) {
                        FitText(row.label, 11f, s, true, Color.Black)
                    }
                    Box(Modifier.weight(1f).height((9 * s).dp).background(FitLabDesign.field, CircleShape)) {
                        Box(
                            Modifier.fillMaxWidth((row.score / 100.0).coerceIn(0.0, 1.0).toFloat())
                                .fillMaxHeight()
                                .background(FitLabDesign.ink, CircleShape),
                        )
                    }
                    Box(Modifier.width((34 * s).dp), contentAlignment = Alignment.CenterEnd) {
                        FitText(score(row.score), 11f, s, true, Color.Black)
                    }
                }
                FitText(when (row.key) {
                    "silhouette" -> "옷 종류별 주요 부위와 길이의 유사도"
                    "mobility" -> "어깨·소매 또는 힙·밑위의 유사도"
                    "layering" -> "가슴·어깨 공간의 유사도"
                    else -> ""
                }, 10f, s, color = Color.Black.copy(alpha = .55f))
            }
        }
    }
}

@Composable
private fun MeasurementScores(rows: List<FitLabMeasurementScore>, s: Float) {
    if (rows.isEmpty()) return
    Column(Modifier.fillMaxWidth().testTag("fitlab-measurement-scores")) {
        Panel(s) {
            CoorditText("PART SCORE BREAKDOWN", CoorditTypography.mona12(16 * s).copy(color = Color.Black))
            FitText("100점에 가까울수록 기준 옷의 실측과 비슷해요. 옷 종류와 의도된 핏에 따라 차이를 다르게 반영해요.", 10f, s, color = Color.Black.copy(alpha = .55f))
            rows.forEach { row ->
                val (fitLabel, fitColor) = measurementScoreStatus(row)
                Column(
                    Modifier.fillMaxWidth().heightIn(min = (58 * s).dp).testTag("fitlab-measurement-score-${row.measurement}"),
                    verticalArrangement = Arrangement.spacedBy((6 * s).dp),
                ) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        FitText(row.label, 11f, s, true, Color.Black)
                        Spacer(Modifier.weight(1f))
                        FitText("${score(row.score)}점", 11f, s, true, Color.Black)
                    }
                    Box(Modifier.fillMaxWidth().height((8 * s).dp).background(FitLabDesign.field, CircleShape)) {
                        Box(
                            Modifier.fillMaxWidth((row.score / 100.0).coerceIn(0.0, 1.0).toFloat())
                                .fillMaxHeight()
                                .background(FitLabDesign.ink, CircleShape),
                        )
                    }
                    FitText(measurementScoreDifference(row.diff, fitLabel), 9f, s, true, fitColor)
                }
            }
        }
    }
}

private fun measurementScoreStatus(row: FitLabMeasurementScore): Pair<String, Color> = when (row.status?.lowercase()) {
    "tight", "too_tight", "small", "slightly_small", "too_small", "타이트" -> "타이트" to AppColors.danger
    "loose", "too_loose", "large", "slightly_large", "too_large", "여유" -> "여유" to AppColors.blue
    "good", "very_similar", "similar", "same", "비슷" -> "비슷" to AppColors.green
    else -> when {
        kotlin.math.abs(row.diff) < .001 -> "비슷" to AppColors.green
        row.diff < 0 -> "타이트" to AppColors.danger
        else -> "여유" to AppColors.blue
    }
}

private fun measurementScoreDifference(diff: Double, status: String): String =
    if (kotlin.math.abs(diff) < .001) "기준 대비 ±0cm · $status"
    else "기준 대비 ${if (diff > 0) "+" else ""}${number(diff)}cm · $status"

@Composable
private fun DifferenceChart(rows: List<FitLabDifference>, comparisons: List<FitLabComparison>, fallback: Map<String, Double>, s: Float) {
    val values = if (rows.isNotEmpty()) rows.map { row ->
        val comparison = comparisons.firstOrNull { it.measurement == row.measurement || it.label == row.label }
        DifferenceDisplay(row.label, row.diff, comparison?.ideal, comparison?.product)
    } else fallback.map { (key, value) ->
        val comparison = comparisons.firstOrNull { it.measurement == key }
        DifferenceDisplay(measurementName(key), value, comparison?.ideal, comparison?.product)
    }
    if (values.isEmpty()) return
    val maximum = values.maxOf { kotlin.math.abs(it.diff) }.coerceAtLeast(1.0)
    Column(Modifier.fillMaxWidth().testTag("fitlab-difference-chart")) {
    Panel(s) {
        CoorditText("BEST FIT DIFFERENCE", CoorditTypography.mona12(16 * s).copy(color = Color.Black))
        FitText("0을 기준으로 왼쪽은 타이트, 오른쪽은 여유예요.", 10f, s, color = Color.Black.copy(alpha = .55f))
        Row(Modifier.fillMaxWidth()) {
            FitText("− 타이트", 9f, s, true, AppColors.danger)
            Spacer(Modifier.weight(1f)); FitText("0", 9f, s, true, Color.Black.copy(alpha = .5f)); Spacer(Modifier.weight(1f))
            FitText("+ 여유", 9f, s, true, AppColors.blue)
        }
        values.forEach { value ->
            val color = if (kotlin.math.abs(value.diff) <= 1) AppColors.green else if (value.diff > 0) AppColors.blue else AppColors.danger
            Column(verticalArrangement = Arrangement.spacedBy((6 * s).dp)) {
                Row {
                    FitText(value.label, 11f, s, true, Color.Black)
                    if (value.ideal != null && value.product != null) {
                        Spacer(Modifier.width((6 * s).dp))
                        FitText("기준 ${number(value.ideal)} · 상품 ${number(value.product)}", 9f, s, color = Color.Black.copy(alpha = .55f))
                    }
                    Spacer(Modifier.weight(1f))
                    FitText("${if (value.diff > 0) "+" else ""}${number(value.diff)}cm", 11f, s, true, color)
                }
                BoxWithConstraints(Modifier.fillMaxWidth().height((38 * s).dp)) {
                    val ratio = (value.diff / maximum).toFloat()
                    val ballSize = (30 * s).dp
                    val endpoint = maxWidth / 2 + maxWidth * (.44f * ratio)
                    Canvas(Modifier.fillMaxSize()) {
                        val center = Offset(size.width / 2f, size.height / 2f)
                        val endpointX = center.x + size.width * .44f * ratio
                        val path = Path().apply {
                            moveTo(center.x, center.y)
                            cubicTo(
                                center.x + (endpointX - center.x) * .28f, center.y - 4 * s,
                                center.x + (endpointX - center.x) * .68f, center.y + 4 * s,
                                endpointX, center.y,
                            )
                        }
                        drawCircle(Color.Black.copy(alpha = .2f), radius = 2.4f * s, center = center)
                        drawPath(path, color.copy(alpha = .15f), style = Stroke(width = 3.2f * s, cap = StrokeCap.Round))
                        drawPath(path, color.copy(alpha = .88f), style = Stroke(width = 1.7f * s, cap = StrokeCap.Round))
                    }
                    Image(
                        painter = painterResource(R.drawable.coordit_yarn),
                        contentDescription = "${value.label} 차이 실타래",
                        modifier = Modifier.size(ballSize)
                            .offset(x = endpoint - ballSize / 2, y = (4 * s).dp)
                            .clip(CircleShape)
                            .graphicsLayer(rotationZ = ratio * 32f),
                    )
                }
            }
        }
    }
    }
}

private data class DifferenceDisplay(val label: String, val diff: Double, val ideal: Double?, val product: Double?)

@Composable
private fun ReportDetails(report: FitLabReportBody?, chartData: FitLabChartData?, error: String?, s: Float, recommendedSize: String) {
    Column(Modifier.fillMaxWidth().testTag("fitlab-report-details"), verticalArrangement = Arrangement.spacedBy((14 * s).dp)) {
        Column(verticalArrangement = Arrangement.spacedBy((3 * s).dp)) {
            CoorditText("DETAILED FIT ANALYSIS", CoorditTypography.mona12(18 * s).copy(color = Color.Black))
            FitText("기준 의류와 상품 실측을 부위별로 해석했어요.", 10f, s, color = Color.Black.copy(alpha = .55f))
        }
        if (report == null) FitText(error ?: "상세 리포트를 불러오지 못했어요. 추천 점수와 비교 수치는 그대로 확인할 수 있어요.", 12f, s, color = Color.Black)
        report?.let {
            Box(Modifier.semantics(mergeDescendants = true) {}.testTag("fitlab-report-basis")) { FitText("추천 $recommendedSize 사이즈 기준 상세 리포트", 12f, s, true, FitLabDesign.ink) }
            ReportSection("OVERALL VERDICT", it.title, it.summary, true, s)
        }
        report?.garmentFitContext?.takeIf(String::isNotBlank)?.let {
            ReportSection("GARMENT FIT CONTEXT", "이 옷에서 중요한 핏 포인트", it, false, s, "fitlab-report-context")
        }
        report?.recommendationReason?.let {
            ReportSection("WHY THIS SIZE", "이 사이즈를 추천하는 이유", it, false, s)
        }
        report?.sizeTradeoff?.takeIf(String::isNotBlank)?.let {
            ReportSection("SIZE TRADEOFF", "다른 사이즈와 비교하면", it, false, s, "fitlab-report-tradeoff")
        }
        if (!report?.measurementAnalysis.isNullOrEmpty()) FitText("부위별 정밀 분석", 17f, s, true, Color.Black)
        report?.measurementAnalysis?.forEach { analysis ->
            val comparison = chartData?.idealVsProduct?.firstOrNull { it.label == analysis.measurement }
            val direction = comparison?.let(::analysisDirection)
            val railColor = direction?.second ?: Color.Black.copy(alpha = .4f)
            Box(Modifier.fillMaxWidth().testTag("fitlab-report-measurement-${analysis.measurement}")) {
                Panel(s) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        FitText(analysis.measurement, 14f, s, true, Color.Black)
                        Spacer(Modifier.weight(1f))
                        direction?.let { (label, color) ->
                            Box(Modifier.background(color.copy(alpha = .12f), CircleShape).padding(horizontal = (7 * s).dp, vertical = (4 * s).dp)) {
                                FitText(label, 9f, s, true, color)
                            }
                        }
                    }
                    FitText(analysis.text, 12f, s, color = Color.Black)
                }
                Box(Modifier.matchParentSize().padding(vertical = (10 * s).dp)) {
                    Box(Modifier.align(Alignment.CenterStart).width((3 * s).dp).fillMaxHeight().background(railColor, RoundedCornerShape((2 * s).dp)))
                }
            }
        }
        if (!report?.cautions.isNullOrEmpty() || !report?.nextActions.isNullOrEmpty()) {
            Column(Modifier.fillMaxWidth().background(FitLabDesign.field, RoundedCornerShape((9 * s).dp)).padding((16 * s).dp), verticalArrangement = Arrangement.spacedBy((10 * s).dp)) {
                FitText("구매 전 마지막 확인", 15f, s, true, Color.Black)
                report?.cautions?.forEach { FitText("ⓘ  $it", 11f, s, color = Color.Black) }
                report?.nextActions?.forEach { FitText("✓  $it", 11f, s, color = Color.Black) }
            }
        }
    }
}

private fun analysisDirection(comparison: FitLabComparison): Pair<String, Color>? {
    if (!comparison.diff.isFinite()) return null
    val status = comparison.status?.lowercase()
    val tolerance = when (comparison.measurement) {
        "shoulder_width", "waist_width", "rise" -> .5
        "chest_width", "sleeve_length", "hip_width" -> .75
        else -> 1.0
    }
    return when (status) {
        "tight", "too_tight", "small", "slightly_small", "too_small", "타이트" -> "− 타이트" to AppColors.danger
        "good", "very_similar", "similar", "same", "비슷" -> "≈ 비슷" to AppColors.green
        "loose", "too_loose", "large", "slightly_large", "too_large", "여유" -> "+ 여유" to AppColors.blue
        else -> when {
            kotlin.math.abs(comparison.diff) <= tolerance -> "≈ 비슷" to AppColors.green
            comparison.diff < 0 -> "− 타이트" to AppColors.danger
            else -> "+ 여유" to AppColors.blue
        }
    }
}

@Composable
private fun ReportSection(eyebrow: String, title: String, text: String, dark: Boolean, s: Float, tag: String = if (dark) "fitlab-report-overall" else "fitlab-report-reason") {
    Column(Modifier.fillMaxWidth().testTag(tag)) {
    Panel(s, dark = dark) {
        FitText(eyebrow, 10f, s, color = if (dark) Color.White.copy(alpha = .72f) else Color.Black.copy(alpha = .55f))
        FitText(title, 16f, s, true, if (dark) Color.White else Color.Black)
        FitText(text, 12f, s, color = if (dark) Color.White else Color.Black)
    }
    }
}

internal fun measurementName(key:String)=when(key){"shoulder_width"->"어깨";"chest_width"->"가슴";"total_length"->"총장";"sleeve_length"->"소매";"waist_width"->"허리";"hip_width"->"힙";"rise"->"밑위";"outseam"->"총장";else->key}

@Composable internal fun Panel(s:Float,dark:Boolean=false,content:@Composable ColumnScope.()->Unit){val shape=RoundedCornerShape((FitLabDesign.panelRadius*s).dp);Column(Modifier.fillMaxWidth().background(if(dark)FitLabDesign.ink else AppColors.panel,shape).border((.8f*s).dp,Color.Black.copy(alpha=if(dark)0f else .12f),shape).padding((15*s).dp),verticalArrangement=Arrangement.spacedBy((11*s).dp),content=content)}
@Composable internal fun FitText(text:String,size:Float,s:Float,bold:Boolean=false,color:Color=FitLabDesign.ink,light:Boolean=false,lineSpacing:Float=0f){CoorditText(text,(if(bold)CoorditTypography.gmarketBold(size*s)else if(light)CoorditTypography.gmarketLight(size*s)else CoorditTypography.gmarketMedium(size*s)).copy(color=color,lineHeight=if(lineSpacing>0)((size+lineSpacing)*s).sp else androidx.compose.ui.unit.TextUnit.Unspecified,lineBreak=CoorditTypography.koreanParagraph,localeList=CoorditTypography.koreanLocale))}
@Composable private fun Field(value:String,onChange:(String)->Unit,hint:String,tag:String,s:Float,enabled:Boolean=true,url:Boolean=false){BasicTextField(value,onChange,Modifier.fillMaxWidth().heightIn(min=(45*s).dp).background(FitLabDesign.field,RoundedCornerShape((7*s).dp)).padding((11*s).dp).testTag(tag).semantics { contentDescription = hint },enabled=enabled,singleLine=true,keyboardOptions=KeyboardOptions(keyboardType=if(url)KeyboardType.Uri else KeyboardType.Text),textStyle=CoorditTypography.gmarketMedium(12*s),decorationBox={inner->Box{if(value.isBlank())FitText(hint,12f,s,color=Color.Black.copy(alpha=.3f));inner()}})}
@Composable private fun MeasureField(label:String,value:Double?,tag:String,s:Float,modifier:Modifier,onChange:(Double?)->Unit){var text by rememberSaveable(tag){mutableStateOf(value?.let(::number).orEmpty())};LaunchedEffect(value){if(value!=measurementValue(text))text=value?.let(::number).orEmpty()};Row(modifier,verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy((9*s).dp)){FitText(label.removeSuffix(" 단면"),10f,s,color=Color.Black.copy(alpha=.66f));Spacer(Modifier.width((28*s).dp));BasicTextField(text,{if(isMeasurementText(it)){text=it;onChange(measurementValue(it))}},Modifier.weight(1f).height((42*s).dp).background(FitLabDesign.field,RoundedCornerShape((7*s).dp)).padding((10*s).dp).testTag(tag),singleLine=true,keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Decimal),textStyle=CoorditTypography.gmarketBold(14*s),decorationBox={inner->Box{if(text.isEmpty())FitText("cm",11f,s,color=Color.Black.copy(alpha=.3f));inner()}})}}
@Composable private fun Segment(upper:Boolean,s:Float,onChange:(Boolean)->Unit){Row(Modifier.fillMaxWidth().background(FitLabDesign.field,CircleShape).padding((5*s).dp),horizontalArrangement=Arrangement.spacedBy((7*s).dp)){listOf(true,false).forEach{u->Pressable({onChange(u)},Modifier.weight(1f).testTag(if(u)"fitlab-upper" else "fitlab-lower"),cornerRadius=30f){Box(Modifier.fillMaxWidth().height((28*s).dp).background(if(upper==u)FitLabDesign.ink else Color.White.copy(alpha=.65f),CircleShape),contentAlignment=Alignment.Center){FitText(if(u)"상의" else "하의",11f,s,color=if(upper==u)Color.White else FitLabDesign.ink)}}}}}
@Composable private fun CategoryRow(selected:HomeCategory,s:Float,onChange:(HomeCategory)->Unit){Row(Modifier.horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy((7*s).dp)){HomeCategory.entries.filter{it.upper==selected.upper}.forEach{c->Pressable({onChange(c)},Modifier.testTag("fitlab-category-${c.wireName}"),cornerRadius=30f){Box(Modifier.background(if(c==selected)FitLabDesign.ink else FitLabDesign.field,CircleShape).padding(horizontal=(10*s).dp,vertical=(8*s).dp)){FitText(c.title,10f,s,color=if(c==selected)Color.White else FitLabDesign.ink)}}}}}
@Composable private fun CategoryPicker(selected:HomeCategory,s:Float,onChange:(HomeCategory)->Unit){var open by remember{mutableStateOf(false)};Pressable({open=true},Modifier.fillMaxWidth().testTag("fitlab-category-picker"),cornerRadius=7*s){Row(Modifier.fillMaxWidth().background(FitLabDesign.field,RoundedCornerShape((7*s).dp)).padding((11*s).dp)){FitText(selected.title,12f,s,true,Color.Black);Spacer(Modifier.weight(1f));FitText("⌄",14f,s,true,Color.Black)}};if(open)Dialog(onDismissRequest={open=false}){Panel(s){FitText("카테고리",16f,s,true,Color.Black);HomeCategory.entries.filter{it.upper==selected.upper}.forEach{category->Pressable({open=false;onChange(category)},Modifier.fillMaxWidth().testTag("fitlab-category-${category.wireName}"),cornerRadius=7*s){Box(Modifier.fillMaxWidth().background(if(category==selected)FitLabDesign.empty else FitLabDesign.field,RoundedCornerShape((7*s).dp)).padding((12*s).dp)){FitText(category.title,12f,s,category==selected,Color.Black)}}}}}}
@Composable internal fun Primary(text:String,s:Float,tag:String,enabled:Boolean,onClick:()->Unit){Pressable(onClick,Modifier.fillMaxWidth().testTag(tag),enabled,7*s){Box(Modifier.fillMaxWidth().heightIn(min=(48*s).dp).background(if(enabled)FitLabDesign.ink else Color.Black.copy(alpha=.28f),RoundedCornerShape((7*s).dp)),contentAlignment=Alignment.Center){FitText(text,14f,s,true,Color.White.copy(alpha=if(enabled)1f else .55f))}}}
@Composable internal fun Secondary(text:String,s:Float,tag:String,onClick:()->Unit){Pressable(onClick,Modifier.fillMaxWidth().testTag(tag),cornerRadius=7*s){Box(Modifier.fillMaxWidth().heightIn(min=(48*s).dp).background(FitLabDesign.empty,RoundedCornerShape((7*s).dp)),contentAlignment=Alignment.Center){FitText(text,14f,s,true,FitLabDesign.ink)}}}
@Composable private fun LightAction(text:String,s:Float,tag:String,enabled:Boolean,onClick:()->Unit){Pressable(onClick,Modifier.fillMaxWidth().testTag(tag),enabled,7*s){Box(Modifier.fillMaxWidth().heightIn(min=(44*s).dp).background(FitLabDesign.empty.copy(alpha=if(enabled)1f else .55f),RoundedCornerShape((7*s).dp)),contentAlignment=Alignment.Center){FitText(text,13f,s,true,Color.Black.copy(alpha=if(enabled)1f else .45f))}}}
@Composable internal fun Error(message:String,s:Float){Box(Modifier.semantics{liveRegion=LiveRegionMode.Polite}){FitText(message,11f,s,color=AppColors.danger)}}
internal fun number(v:Double)=String.format(Locale.US,"%.2f",v).trimEnd('0').trimEnd('.')
internal fun score(v:Double)=String.format(Locale.US,"%.1f",v)
private fun sourceLabel(source:FitLabSource)=when(source){FitLabSource.Manual->"수동 입력";FitLabSource.Ocr->"OCR 입력";FitLabSource.Url->"링크 입력"}
private fun stepText(step:FitLabStep)=when(step){FitLabStep.Product->"상품 정보를 저장하고 있어요.";FitLabStep.Sizes->"사이즈표를 저장하고 있어요.";FitLabStep.Recommendation->"가장 잘 맞는 사이즈를 계산하고 있어요.";FitLabStep.Report->"핏 리포트를 작성하고 있어요.";else->"기준 의류와 상품 실측을 비교하고 있어요."}
private fun progress(step:FitLabStep)=when(step){FitLabStep.Product->.2f;FitLabStep.Sizes->.42f;FitLabStep.Recommendation->.7f;FitLabStep.Report->.9f;FitLabStep.Complete->1f;else->.08f}
