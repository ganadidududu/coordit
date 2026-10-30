package com.inseong.coordit.ui.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.inseong.coordit.data.home.HomeGarment
import com.inseong.coordit.data.home.HomeSnapshot
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.ui.semantics.contentDescription

data class HomeUiState(
    val snapshot: HomeSnapshot = HomeSnapshot(),
    val loading: Boolean = false,
    val saving: Boolean = false,
    val error: String? = null,
)

@Composable
fun HomeScreen(
    state: HomeUiState,
    onRetry: () -> Unit,
    onReferenceCommit: (Set<String>) -> Unit,
    onCloset: () -> Unit,
    onFitLab: () -> Unit,
    onProfile: () -> Unit,
    history: List<com.inseong.coordit.data.fitlab.FitLabHistorySnapshot> = emptyList(),
    onOpenHistory: (com.inseong.coordit.data.fitlab.FitLabHistorySnapshot) -> Unit = {},
    reduceMotion: Boolean = false,
    onAddGarment: () -> Unit = onCloset,
) {
    var picker by remember { mutableStateOf(false) }
    var awaitingSave by remember { mutableStateOf(false) }
    LaunchedEffect(state.saving) {
        if (state.saving) awaitingSave = true
        else if (awaitingSave) {
            if (state.error == null) picker = false
            awaitingSave = false
        }
    }
    BoxWithConstraints(Modifier.fillMaxSize().testTag("coordit-screen-main04")) {
        val s = maxWidth.value / AppDimensions.designWidth
        SharedAppBackground(s)
        Column(Modifier.fillMaxSize().padding(top = (117 * s).dp).verticalScroll(rememberScrollState()).testTag("home-scroll")
            .padding(bottom = (110 * s).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy((12 * s).dp)) {
            MagazineCard(s, onFitLab, reduceMotion)
            ReferenceCard(state, s, { picker = true }, onRetry)
            FitHistoryCard(s, history, onOpenHistory)
            Pressable(onCloset, Modifier.width((361 * s).dp).height((43 * s).dp)
                .coorditShadow(Color.Black.copy(alpha = .035f), (9 * s).dp, ContinuousRoundedShape((10 * s).dp), (3 * s).dp)
                .background(Brush.verticalGradient(listOf(AppColors.panel, Color(235, 238, 247))), ContinuousRoundedShape((10 * s).dp))
                .testTag("coordit-main04-closet-button")) {
                BasicText("MY CLOSET", Modifier.fillMaxWidth().padding(horizontal = (12 * s).dp),
                    style = CoorditTypography.climate2019(17.2f * s).copy(color = Color.Black, letterSpacing = (-.86f * s).sp))
            }
        }
        CoorditHeader(s, onProfile, Modifier.align(Alignment.TopCenter).padding(top = (59 * s).dp))
        CoorditBottomNavigation(CoorditTab.Home, s, { tab ->
            when (tab) { CoorditTab.Home -> Unit; CoorditTab.FitLab -> onFitLab(); CoorditTab.Closet -> onCloset() }
        }, Modifier.align(Alignment.BottomCenter))
    }
    if (picker) ReferencePicker(state, onDismiss = { if (!state.saving) picker = false }, onAdd = {
        picker = false
        onAddGarment()
    }, onCommit = onReferenceCommit)
}

private data class MagazineIssue(val kicker: String, val title: String, val body: String)
private val issues = listOf(
    MagazineIssue("FIT GUIDE", "새 옷,\n잘 맞을까?", "평소 잘 맞는 옷과 비교해\n사이즈 선택을 가볍게."),
    MagazineIssue("MY REFERENCE", "잘 맞는 옷이\n기준이 되니까", "내 옷장에서 기준을 고르고\n실측 차이를 확인해요."),
    MagazineIssue("LAYERING", "겹쳐 입어도,\n나답게", "어깨부터 소매까지,\n옷의 여유를 살펴보세요."),
)

@Composable
private fun MagazineCard(s: Float, onFitLab: () -> Unit, reduceMotion: Boolean) {
    val pager = rememberPagerState(pageCount = { issues.size })
    val scope = rememberCoroutineScope()
    val context = androidx.compose.ui.platform.LocalContext.current
    val accessibility = context.getSystemService(android.content.Context.ACCESSIBILITY_SERVICE) as android.view.accessibility.AccessibilityManager
    val largeText = LocalDensity.current.fontScale >= 1.5f
    LaunchedEffect(pager, reduceMotion, largeText) {
        if (!reduceMotion && !largeText) while (true) {
            delay(7_000)
            if (!pager.isScrollInProgress && !accessibility.isTouchExplorationEnabled) pager.animateScrollToPage((pager.currentPage + 1) % issues.size)
        }
    }
    Box(Modifier.width((366 * s).dp).background(AppColors.panel, ContinuousRoundedShape((12 * s).dp))
        .border(.7.dp, AppColors.line.copy(alpha = .65f), ContinuousRoundedShape((12 * s).dp)).clip(ContinuousRoundedShape((12 * s).dp)).testTag("coordit-main04-banner")) {
        if (!largeText) androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(com.inseong.coordit.R.drawable.coordit_home_editorial), null,
            Modifier.align(Alignment.CenterEnd).offset(x = (9 * s).dp).size((205 * s).dp, (248 * s).dp), contentScale = androidx.compose.ui.layout.ContentScale.Fit)
        Column(Modifier.fillMaxWidth().padding(top = (14 * s).dp), verticalArrangement = Arrangement.spacedBy((12 * s).dp)) {
            HorizontalPager(pager, Modifier.fillMaxWidth().then(if (largeText) Modifier else Modifier.height((180 * s).dp)).testTag("coordit-main04-fashion-magazine-carousel")) { index ->
                val issue = issues[index]
                Column(Modifier.padding(horizontal = (18 * s).dp).then(if (largeText) Modifier.fillMaxWidth() else Modifier.width((160 * s).dp)), verticalArrangement = Arrangement.spacedBy((12 * s).dp)) {
                    Box(Modifier.background(AppColors.ink, CircleShape).padding(horizontal = (10 * s).dp, vertical = (7 * s).dp)) {
                        CoorditText(issue.kicker, CoorditTypography.gmarketBold(9 * s).copy(color = Color.White))
                    }
                    CoorditText(issue.title, CoorditTypography.gmarketBold(27 * s))
                    CoorditText(issue.body, CoorditTypography.gmarketMedium(10 * s).copy(color = AppColors.muted))
                    CoorditText("COORDIT MAGAZINE", CoorditTypography.gmarketMedium(7 * s).copy(color = AppColors.muted, letterSpacing = (.8f * s).sp))
                    if (largeText) androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(com.inseong.coordit.R.drawable.coordit_home_editorial), null, Modifier.fillMaxWidth().height((140 * s).dp))
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = (16 * s).dp).padding(bottom = (14 * s).dp), verticalAlignment = Alignment.CenterVertically) {
                Pressable(onFitLab, Modifier.heightIn(min = 44.dp).background(AppColors.ink, CircleShape).padding(horizontal = (16 * s).dp).testTag("coordit-main04-new-fit-button"), cornerRadius = 30f) {
                    CoorditText("새로운 옷 찾기", CoorditTypography.gmarketBold(12 * s).copy(color = Color.White))
                }
                Spacer(Modifier.weight(1f))
                issues.indices.forEach { index ->
                    Pressable({ scope.launch { if (reduceMotion) pager.scrollToPage(index) else pager.animateScrollToPage(index) } }, Modifier.size(44.dp).semantics { selected = index == pager.currentPage; contentDescription = "매거진 ${index + 1}페이지" }) {
                        Box(Modifier.width(((if (index == pager.currentPage) 16 else 5) * s).dp).height((5 * s).dp).background(AppColors.ink.copy(alpha = if (index == pager.currentPage) 1f else .22f), CircleShape))
                    }
                }
            }
        }
    }
}

@Composable
private fun FitHistoryCard(s: Float, history: List<com.inseong.coordit.data.fitlab.FitLabHistorySnapshot>, open: (com.inseong.coordit.data.fitlab.FitLabHistorySnapshot) -> Unit) {
    val recent = history.sortedWith(compareByDescending<com.inseong.coordit.data.fitlab.FitLabHistorySnapshot> { it.savedAt }.thenByDescending { it.analysisId }).take(2)
    Column(Modifier.width((366 * s).dp).background(AppColors.panel, ContinuousRoundedShape((12 * s).dp))
        .padding(horizontal = (16 * s).dp, vertical = (14 * s).dp).testTag("coordit-main04-fitlab-card"), verticalArrangement = Arrangement.spacedBy((6 * s).dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            CoorditText("최근 핏 분석", CoorditTypography.gmarketBold(17 * s))
            Spacer(Modifier.weight(1f))
            CoorditText("최근 저장 ${recent.size}개", CoorditTypography.gmarketMedium(9 * s).copy(color = AppColors.muted))
        }
        if (recent.isEmpty()) Box(Modifier.fillMaxWidth().heightIn(min = (54 * s).dp).background(Color.Black.copy(alpha = .035f), ContinuousRoundedShape((6 * s).dp)).testTag("coordit-main04-history-empty"), contentAlignment = Alignment.Center) {
            CoorditText("저장한 핏 리포트가 아직 없어요", CoorditTypography.gmarketMedium(10 * s).copy(color = Color.Black.copy(alpha = .55f)))
        } else {
            @Composable fun Item(snapshot: com.inseong.coordit.data.fitlab.FitLabHistorySnapshot, modifier: Modifier) {
                val result = snapshot.recommendation
                val tint = if (snapshot.upper) AppColors.blue else AppColors.green
                Pressable({ open(snapshot) }, modifier.testTag("coordit-main04-history-card-${snapshot.analysisId}"), cornerRadius = 6 * s) {
                    Row(Modifier.fillMaxWidth().heightIn(min = (54 * s).dp).background(Brush.horizontalGradient(listOf(Color.White.copy(alpha = .98f), tint.copy(alpha = .08f))), ContinuousRoundedShape((6 * s).dp)).padding((10 * s).dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((7 * s).dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((4 * s).dp)) {
                            Label(snapshot.productName, CoorditTypography.gmarketBold(10 * s))
                            Label("${if (snapshot.upper) "TOP" else "BOTTOM"} · ${result.recommendedSize} 추천", CoorditTypography.gmarketMedium(8.2f * s).copy(color = AppColors.muted))
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Label("SCORE", CoorditTypography.mona12(7.4f * s).copy(color = AppColors.muted))
                            Label(String.format(java.util.Locale.US, "%.1f", result.fitScore), CoorditTypography.mona12(19 * s))
                        }
                    }
                }
            }
            if (LocalDensity.current.fontScale >= 1.5f) recent.forEach { Item(it, Modifier.fillMaxWidth()) }
            else Row(horizontalArrangement = Arrangement.spacedBy((8 * s).dp)) { recent.forEach { Item(it, Modifier.weight(1f)) } }
        }
    }
}

@Composable
private fun ReferenceCard(state: HomeUiState, s: Float, onSelect: () -> Unit, onRetry: () -> Unit) {
    val items = state.snapshot.items
    val selected = state.snapshot.selectedIds
    val previews = items.filter { it.id in selected }.ifEmpty { items }.take(3)
    Column(Modifier.width((361 * s).dp).background(AppColors.panel, ContinuousRoundedShape((10 * s).dp))
        .border((.8f * s).dp, AppColors.ink.copy(alpha = .08f), ContinuousRoundedShape((10 * s).dp))
        .padding((13 * s).dp).testTag("home-reference-card"), verticalArrangement = Arrangement.spacedBy((9 * s).dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy((10 * s).dp), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((3 * s).dp)) {
                Label("기준 의류", CoorditTypography.gmarketBold(14 * s))
                BasicText(when {
                    state.loading -> "기준 의류를 불러오고 있어요."
                    state.error != null && items.isEmpty() -> "기준 의류를 불러오지 못했어요."
                    items.isEmpty() -> "옷장에 의류를 추가한 뒤 기준 옷으로 선택할 수 있어요."
                    selected.isEmpty() -> "등록된 상·하의 ${items.size}개 중 잘 맞는 옷을 골라주세요."
                    else -> "선택한 기준 의류 ${selected.size}개를 핏 계산에 사용해요."
                }, Modifier.widthIn(max = (200 * s).dp), style = CoorditTypography.gmarketMedium(9.5f * s).copy(color = AppColors.ink.copy(alpha = .55f)))
            }
            Pressable(onSelect, Modifier.height((36 * s).dp).background(AppColors.ink, CircleShape).padding(horizontal = (11 * s).dp)
                .testTag("home-reference-select"), enabled = !state.loading && !state.saving, cornerRadius = 36 * s) {
                Label(if (selected.isEmpty()) "옷장에서 선택" else "다시 선택", CoorditTypography.gmarketBold(9.5f * s).copy(color = Color.White))
            }
        }
        if (previews.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy((8 * s).dp)) {
            previews.forEach { item -> Row(Modifier.weight(1f).testTag("home-reference-preview-${item.id}"), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((6 * s).dp)) {
                GarmentThumbnail(item, Modifier.size((34 * s).dp, (46 * s).dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy((2 * s).dp)) {
                    Label(item.name, CoorditTypography.gmarketBold(8.5f * s))
                    Label(item.category.title, CoorditTypography.gmarketMedium(7.5f * s).copy(color = AppColors.ink.copy(alpha = .48f)))
                }
            } }
        }
        if (state.error != null) {
            BasicText(state.error, Modifier.testTag("home-reference-sync-status"), style = CoorditTypography.gmarketMedium(9.5f * s).copy(color = AppColors.danger))
            Pressable(onRetry, Modifier.heightIn(min = 44.dp), enabled = !state.loading && !state.saving) { Label("다시 시도", CoorditTypography.gmarketBold(11 * s)) }
        }
    }
}

@Composable
private fun ReferencePicker(state: HomeUiState, onDismiss: () -> Unit, onAdd: () -> Unit, onCommit: (Set<String>) -> Unit) {
    var selection by remember { mutableStateOf(state.snapshot.selectedIds.intersect(state.snapshot.items.map { it.id }.toSet())) }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(.92f).clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)).background(AppColors.appBackground).testTag("home-reference-sheet")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                Pressable(onDismiss, Modifier.heightIn(min = 44.dp), enabled = !state.saving) { Label("취소", CoorditTypography.gmarketMedium(12f)) }
                Label("기준 의류", CoorditTypography.gmarketBold(16f))
                Pressable({ onCommit(selection) }, Modifier.heightIn(min = 44.dp).testTag("home-reference-done"), enabled = state.snapshot.items.isNotEmpty() && !state.saving) {
                    Label(if (state.saving) "저장 중…" else "선택 완료", CoorditTypography.gmarketBold(12f))
                }
            }
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                BasicText("상의와 하의에서 실제로 잘 맞는 옷을 여러 개 선택할 수 있어요.", style = CoorditTypography.gmarketMedium(11f).copy(color = AppColors.ink.copy(alpha = .58f)))
                state.error?.let { BasicText(it, style = CoorditTypography.gmarketMedium(11f).copy(color = AppColors.danger)) }
                if (state.snapshot.items.isEmpty()) {
                    Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(9.dp)).padding(vertical = 34.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Label("아직 옷장에 등록된 의류가 없어요.", CoorditTypography.gmarketBold(14f))
                        CoorditButton("새 의류 등록하기", onAdd, Modifier.padding(horizontal = 16.dp), height = 44f, fontSize = 12f)
                    }
                } else {
                    listOf(true, false).forEach { upper ->
                        val title = if (upper) "상의" else "하의"
                        val items = state.snapshot.items.filter { it.category.upper == upper }
                        Column(Modifier.fillMaxWidth().background(AppColors.panel, RoundedCornerShape(9.dp)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                            Label(title, CoorditTypography.gmarketBold(14f))
                            if (items.isEmpty()) BasicText("등록된 $title 의류가 없어요.", Modifier.padding(vertical = 12.dp), style = CoorditTypography.gmarketMedium(11f).copy(color = AppColors.ink.copy(alpha = .48f)))
                            items.forEach { item ->
                                val chosen = item.id in selection
                                Pressable({ selection = if (chosen) selection - item.id else selection + item.id },
                                    Modifier.fillMaxWidth().heightIn(min = 82.dp).background(if (chosen) AppColors.closetField else Color.Transparent, RoundedCornerShape(8.dp))
                                        .semantics { selected = chosen }.testTag("home-reference-item-${item.id}"), enabled = !state.saving) {
                                    Row(Modifier.fillMaxWidth().padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                        GarmentThumbnail(item, Modifier.size(52.dp, 70.dp))
                                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                            Label(item.name, CoorditTypography.gmarketBold(13f))
                                            Label("$title · ${item.category.title}", CoorditTypography.gmarketMedium(10f).copy(color = AppColors.ink.copy(alpha = .52f)))
                                        }
                                        Label(if (chosen) "●" else "○", CoorditTypography.gmarketBold(21f))
                                    }
                                }
                            }
                        }
                    }
                    CoorditButton("새 의류 등록하기", onAdd, secondary = true, enabled = !state.saving, height = 44f, fontSize = 12f)
                }
            }
        }
    }
}

@Composable
private fun GarmentThumbnail(item: HomeGarment, modifier: Modifier) {
    Box(modifier.clip(RoundedCornerShape(7.dp)).background(Brush.verticalGradient(listOf(Color(226, 230, 238), Color(239, 242, 247))))
        .border(1.dp, AppColors.line, RoundedCornerShape(7.dp)), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(if (item.category.upper) 22.dp else 24.dp, if (item.category.upper) 22.dp else 28.dp)) {
            val shape = Path().apply {
                if (item.category.upper) {
                    moveTo(size.width * .3f, 0f); lineTo(0f, size.height * .2f)
                    lineTo(size.width * .12f, size.height * .45f); lineTo(size.width * .25f, size.height * .35f)
                    lineTo(size.width * .25f, size.height); lineTo(size.width * .75f, size.height)
                    lineTo(size.width * .75f, size.height * .35f); lineTo(size.width * .88f, size.height * .45f)
                    lineTo(size.width, size.height * .2f); lineTo(size.width * .7f, 0f)
                    quadraticTo(size.width * .5f, size.height * .25f, size.width * .3f, 0f)
                } else {
                    moveTo(size.width * .12f, 0f); lineTo(size.width * .88f, 0f)
                    lineTo(size.width, size.height); lineTo(size.width * .58f, size.height)
                    lineTo(size.width * .5f, size.height * .4f); lineTo(size.width * .42f, size.height)
                    lineTo(0f, size.height)
                }
                close()
            }
            if (item.category.upper) drawPath(shape, AppColors.ink.copy(alpha = .18f), style = androidx.compose.ui.graphics.drawscope.Stroke(2.dp.toPx()))
            else drawPath(shape, AppColors.ink.copy(alpha = .18f))
        }
    }
}

@Composable
private fun Label(text: String, style: TextStyle, modifier: Modifier = Modifier) {
    BasicText(text, modifier, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
}
