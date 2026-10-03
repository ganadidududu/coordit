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
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(top = (121 * s).dp, bottom = (106 * s).dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy((16 * s).dp)) {
            MagazineCard(s)
            FitHistoryCard(s, onFitLab)
            ReferenceCard(state, s, { picker = true }, onRetry)
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
        onCloset()
    }, onCommit = onReferenceCommit)
}

private data class MagazineIssue(val kicker: String, val status: String, val title: String, val body: String, val tags: List<String>, val tint: Color)
private val issues = listOf(
    MagazineIssue("SALE RADAR", "지난 세일 체크", "무진장·직잭팟은 끝. 다음은 장바구니 정리",
        "여름 대형 세일은 대부분 6월 말에 종료. 지금은 위시템 사이즈를 먼저 검증할 타이밍.", listOf("MUSINSA", "ZIGZAG", "SIZE CHECK"), Color(55, 75, 156)),
    MagazineIssue("NEXT DROP", "곧 볼 구간", "에이블리 여름 클리어런스는 7월 말부터 주시",
        "플랫폼별 시즌오프가 이어지는 구간. 인기 옵션은 빠르게 빠지니 대체 사이즈까지 준비.", listOf("ABLY", "CLEARANCE", "WISHLIST"), Color(24, 132, 122)),
    MagazineIssue("TREND NOW", "2026 S/S", "레드 포인트, 포엣 코어, 가벼운 로맨틱 무드",
        "작은 포인트가 쉬운 시즌. 키링, 셔츠, 얇은 레이어로 시작.", listOf("RED", "POET CORE", "LAYER"), Color(177, 51, 68)),
)

@Composable
private fun MagazineCard(s: Float) {
    val pager = rememberPagerState(pageCount = { issues.size })
    LaunchedEffect(pager) {
        while (true) {
            delay(4_000)
            if (!pager.isScrollInProgress) pager.animateScrollToPage((pager.currentPage + 1) % issues.size)
        }
    }
    Column(Modifier.width((361 * s).dp).height((259 * s).dp)
        .coorditShadow(Color.Black.copy(alpha = .035f), (12 * s).dp, ContinuousRoundedShape((10 * s).dp), (4 * s).dp)
        .background(Brush.linearGradient(listOf(AppColors.panel, Color(238, 242, 250), Color(228, 233, 246))), ContinuousRoundedShape((10 * s).dp))
        .testTag("coordit-main04-banner"), verticalArrangement = Arrangement.spacedBy((8 * s).dp)) {
        BasicText("MAGAZINE", Modifier.padding(top = (15 * s).dp, start = (14 * s).dp),
            style = CoorditTypography.climate2019(17 * s).copy(letterSpacing = (-.6f * s).sp))
        HorizontalPager(pager, Modifier.height((186 * s).dp).testTag("coordit-main04-fashion-magazine-carousel")) { index ->
            val issue = issues[index]
            Column(Modifier.padding(horizontal = (14 * s).dp).fillMaxSize()
                .background(Color.White.copy(alpha = .58f), ContinuousRoundedShape((8 * s).dp))
                .border((.8f * s).dp, Color.White.copy(alpha = .75f), ContinuousRoundedShape((8 * s).dp)).padding((15 * s).dp),
                verticalArrangement = Arrangement.spacedBy((9 * s).dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((7 * s).dp)) {
                    Box(Modifier.background(issue.tint, CircleShape).height((20 * s).dp).padding(horizontal = (8 * s).dp), contentAlignment = Alignment.Center) {
                        Label(issue.kicker, CoorditTypography.mona12(10 * s).copy(color = Color.White))
                    }
                    Label(issue.status, CoorditTypography.gmarketBold(8.5f * s).copy(color = issue.tint))
                }
                FittedMagazineText(issue.title, CoorditTypography.gmarketBold(25 * s), minimumScale = .78f)
                FittedMagazineText(issue.body, CoorditTypography.gmarketMedium(10.5f * s).copy(color = AppColors.ink.copy(alpha = .62f)), minimumScale = .82f)
                Spacer(Modifier.weight(1f))
                Row(horizontalArrangement = Arrangement.spacedBy((6 * s).dp)) {
                    issue.tags.forEach { tag ->
                        Box(Modifier.background(Color.White.copy(alpha = .55f), CircleShape).height((21 * s).dp).padding(horizontal = (7 * s).dp), contentAlignment = Alignment.Center) {
                            Label(tag, CoorditTypography.gmarketBold(8 * s).copy(color = AppColors.ink.copy(alpha = .7f)))
                        }
                    }
                }
            }
        }
        Row(Modifier.padding(horizontal = (15 * s).dp), horizontalArrangement = Arrangement.spacedBy((5 * s).dp)) {
            issues.indices.forEach { index -> Box(Modifier.width(((if (index == pager.currentPage) 18 else 6) * s).dp)
                .height((6 * s).dp).background(AppColors.ink.copy(alpha = if (index == pager.currentPage) 1f else .18f), CircleShape)) }
        }
    }
}

@Composable
private fun FitHistoryCard(s: Float, onFitLab: () -> Unit) {
    Column(Modifier.width((361 * s).dp).height((170 * s).dp)
        .coorditShadow(Color.Black.copy(alpha = .04f), (12 * s).dp, ContinuousRoundedShape((10 * s).dp), (4 * s).dp).background(AppColors.panel, ContinuousRoundedShape((10 * s).dp))
        .padding(horizontal = (16 * s).dp).padding(top = (14 * s).dp).testTag("coordit-main04-fitlab-card")) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy((7 * s).dp)) {
            Label("FIT LAB", CoorditTypography.climate2019(18.6f * s).copy(color = Color.Black, letterSpacing = (-.93f * s).sp))
            Label("당신에게 꼭 맞는 사이즈 설계", CoorditTypography.gmarketMedium(8.8f * s).copy(color = Color.Black))
        }
        Spacer(Modifier.height((5 * s).dp))
        Pressable(onFitLab, Modifier.fillMaxWidth().height((36 * s).dp).background(AppColors.ink, CircleShape).testTag("coordit-main04-new-fit-button")) {
            Label("새로운 옷 찾기", CoorditTypography.gmarketBold(11.5f * s).copy(color = Color.White))
        }
        Row(Modifier.padding(top = (7 * s).dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Label("HISTORY", CoorditTypography.climate2019(8.8f * s).copy(color = Color.Black, letterSpacing = (-.35f * s).sp))
            Label("최근 저장 2개", CoorditTypography.gmarketMedium(8.2f * s).copy(color = Color.Black.copy(alpha = .48f)))
        }
        Box(Modifier.padding(top = (6 * s).dp).fillMaxWidth().height((54 * s).dp)
            .background(Color.Black.copy(alpha = .035f), ContinuousRoundedShape((6 * s).dp)).testTag("coordit-main04-history-empty"), contentAlignment = Alignment.Center) {
            Label("저장한 핏 리포트가 아직 없어요", CoorditTypography.gmarketMedium(10 * s).copy(color = Color.Black.copy(alpha = .55f)))
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
    Box(modifier.background(Brush.verticalGradient(listOf(Color(226, 230, 238), Color(239, 242, 247)))), contentAlignment = Alignment.Center) {
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
            drawPath(shape, AppColors.ink.copy(alpha = .18f))
        }
    }
}

@Composable
private fun Label(text: String, style: TextStyle, modifier: Modifier = Modifier) {
    BasicText(text, modifier, style = style, maxLines = 1, overflow = TextOverflow.Ellipsis)
}

@Composable
private fun FittedMagazineText(text: String, style: TextStyle, minimumScale: Float) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val maximumWidth = with(density) { maxWidth.roundToPx() }
        val fittedStyle = remember(text, style, minimumScale, maximumWidth, density.fontScale) {
            var candidate = style.copy(lineBreak = CoorditTypography.koreanParagraph, localeList = CoorditTypography.koreanLocale)
            val minimumSize = style.fontSize.value * minimumScale
            while (candidate.fontSize.value > minimumSize && measurer.measure(text, candidate,
                    maxLines = 2, constraints = Constraints(maxWidth = maximumWidth)).hasVisualOverflow) {
                candidate = candidate.copy(fontSize = (candidate.fontSize.value - .25f).coerceAtLeast(minimumSize).sp)
            }
            candidate
        }
        BasicText(text, style = fittedStyle, maxLines = 2, overflow = TextOverflow.Ellipsis)
    }
}
