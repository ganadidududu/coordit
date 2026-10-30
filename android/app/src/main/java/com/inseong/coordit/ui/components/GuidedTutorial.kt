package com.inseong.coordit.ui.components

import android.content.Context
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.inseong.coordit.ui.theme.*
import kotlinx.coroutines.delay
import androidx.core.content.edit

private class TutorialState(context: Context, val feature: String) {
    private val preferences = context.getSharedPreferences("guided-tutorials", Context.MODE_PRIVATE)
    var enabled by mutableStateOf(!preferences.getBoolean("$feature.seen", false))
    var target by mutableStateOf<String?>(null)
    var bounds by mutableStateOf<Rect?>(null)
    fun dismiss() { preferences.edit { putBoolean("$feature.seen", true) }; enabled = false; bounds = null }
    fun replay() { enabled = true; bounds = null }
}

private val LocalTutorial = staticCompositionLocalOf<TutorialState?> { null }

@Composable
fun tutorialDismissAction(): () -> Unit {
    val tutorial = LocalTutorial.current
    return { tutorial?.dismiss() }
}

@Composable
fun GuidedScreen(feature: String, target: String?, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val tutorial = remember(feature) { TutorialState(context.applicationContext, feature) }
    var root by remember { mutableStateOf(Rect.Zero) }
    SideEffect { if (tutorial.target != target) { tutorial.bounds = null; tutorial.target = target } }
    CompositionLocalProvider(LocalTutorial provides tutorial) {
        Box(Modifier.fillMaxSize().onGloballyPositioned { root = it.boundsInRoot() }) {
            content()
            val bounds = tutorial.bounds
            if (tutorial.enabled && target != null && bounds != null) {
                Canvas(Modifier.fillMaxSize().testTag("$feature-tutorial-spotlight")) {
                    val inset = 6.dp.toPx()
                    val visible = Rect(0f, 175.dp.toPx(), size.width, (size.height - 104.dp.toPx()).coerceAtLeast(175.dp.toPx()))
                    val translated = bounds.translate(-root.left, -root.top).inflate(inset).intersect(visible)
                    val path = Path().apply {
                        fillType = PathFillType.EvenOdd
                        addRect(Rect(0f, 0f, size.width, size.height))
                        if (!translated.isEmpty) addRoundRect(RoundRect(translated, CornerRadius(10.dp.toPx())))
                    }
                    drawPath(path, Color.Black.copy(alpha = .26f))
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun GuideTarget(id: String, scale: Float, title: String? = null, message: String? = null, finish: Boolean = false, content: @Composable () -> Unit) {
    val tutorial = LocalTutorial.current
    val active = tutorial?.enabled == true && tutorial.target == id
    val bringIntoView = remember { BringIntoViewRequester() }
    LaunchedEffect(active) {
        if (active) { delay(150); bringIntoView.bringIntoView() }
    }
    Column(Modifier.fillMaxWidth().bringIntoViewRequester(bringIntoView).onGloballyPositioned {
        if (active) tutorial?.bounds = it.boundsInRoot()
    }, verticalArrangement = Arrangement.spacedBy((12 * scale).dp)) {
        if (active) {
            val copy = tutorialCopy(tutorial.feature, id)
            Column(Modifier.fillMaxWidth().background(AppColors.panel, ContinuousRoundedShape((10 * scale).dp))
                .border(1.dp,AppColors.line,ContinuousRoundedShape((10*scale).dp))
                .padding((16 * scale).dp).testTag("${tutorial.feature}-tutorial-step-$id"), verticalArrangement = Arrangement.spacedBy((12 * scale).dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    CoorditText(if (tutorial.feature == "closet") "CLOSET 가이드" else "FIT LAB 가이드", CoorditTypography.gmarketMedium(11 * scale), Modifier.weight(1f))
                    Pressable(tutorial::dismiss, Modifier.heightIn(min = 44.dp).testTag("${tutorial.feature}-tutorial-dismiss")) {
                        CoorditText("도움말 닫기", CoorditTypography.gmarketMedium(12 * scale))
                    }
                }
                CoorditText(title ?: copy.first, CoorditTypography.gmarketBold(14 * scale))
                CoorditText(message ?: copy.second, CoorditTypography.gmarketMedium(12 * scale).copy(lineHeight=(17*scale).sp,lineBreak=CoorditTypography.koreanParagraph,localeList=CoorditTypography.koreanLocale))
                if (finish) CoorditButton("가이드 마치기", tutorial::dismiss, Modifier.testTag("${tutorial.feature}-tutorial-finish"))
                CoorditText("↓",CoorditTypography.gmarketMedium(22*scale))
            }
        }
        Box(Modifier.fillMaxWidth().then(if (active) Modifier.border(2.dp, AppColors.ink, ContinuousRoundedShape(10.dp)).padding(4.dp) else Modifier)) {
            content()
        }
    }
}

@Composable
fun GuideReplay(scale: Float, onReplay: () -> Unit = {}) {
    val tutorial = LocalTutorial.current ?: return
    Pressable({ tutorial.replay(); onReplay() }, Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("${tutorial.feature}-tutorial-restart")) {
        CoorditText("사용 가이드 다시 보기", CoorditTypography.gmarketMedium(12 * scale).copy(color = AppColors.muted))
    }
}

private fun tutorialCopy(feature: String, id: String): Pair<String, String> = if (feature == "closet") when (id) {
    "add" -> "보유 의류 추가하기" to "보유 의류 추가하기 버튼으로 내 옷을 등록합니다. 등록한 옷 중 기준 의류로 선택한 데이터가 나의 ‘100점 핏 사이즈’ 계산에 반영됩니다."
    "method" -> "등록 방식 선택하기" to "상품 링크, 사이즈표 사진, 직접 입력 중 가진 정보에 맞는 방식을 선택하세요. 선택한 방식으로 실측을 확인한 뒤 내 옷을 등록해요."
    "link" -> "상품 링크 입력하기" to "보유한 옷의 상품 링크를 아래 입력란에 붙여 넣습니다. 옷 종류도 실제 보유한 의류에 맞게 선택합니다."
    "analyze" -> "링크 분석하기" to "링크 분석하기를 누르면 상품명과 사이즈별 실측 정보를 불러옵니다. 분석이 완료되면 사이즈를 선택합니다."
    "size" -> "내 사이즈 선택하기" to "사이즈표에서 실제로 보유한 옷의 사이즈를 누릅니다. 선택한 사이즈의 실측 정보가 저장됩니다."
    "register" -> "선택한 사이즈 등록하기" to "선택한 사이즈로 등록을 누르면 이 옷을 Closet에 저장합니다. 저장이 완료되면 핏 스코어를 확인합니다."
    else -> "핏 스코어 확인하기" to "등록한 의류의 핏 스코어입니다. 나에게 잘 맞는 옷을 기준 의류로 선택하면, 그 실측 데이터로 ‘100점 핏 사이즈’를 계산합니다."
} else when (id) {
    "source" -> "입력 방식 선택하기" to "실제 핏 분석에는 Closet에 등록하고 기준 의류로 선택한 옷이 필요해요. 준비됐다면 링크·사진·직접 입력 중 편한 방식을 고르세요. 예시 체험에는 샘플 기준 의류가 제공돼요."
    "link" -> "상품 링크 입력하기" to "상품 페이지 주소를 입력하거나 붙여넣고 다음을 누릅니다. 옷 종류도 상품에 맞게 선택합니다."
    "import" -> "상품 정보 불러오기" to "링크에서 가져오기를 누르면 상품 정보와 사이즈표를 불러옵니다. 아직 분석이나 실타래 사용은 진행되지 않습니다."
    "review" -> "사이즈표 확인하기" to "위의 상품명과 사이즈별 실측을 확인합니다. 잘못된 값은 수정하고 확인 버튼을 누릅니다."
    "continue" -> "기준 옷 선택으로 이동하기" to "확인한 사이즈표로 비교를 준비합니다. 기준 옷 선택으로 버튼을 누릅니다."
    "references" -> "나에게 잘 맞는 기준 옷 선택하기" to "비슷한 종류와 길이의 기준 옷을 한 개 이상 선택합니다. 기준 옷이 없다면 먼저 선택·등록합니다."
    "analyze" -> "핏 분석 시작하기" to "선택한 기준 옷과 상품의 사이즈를 비교합니다. 핏 분석을 시작하면 실타래 1개가 사용됩니다."
    "result" -> "사이즈별 핏 비교하기" to "추천 사이즈와 핏 점수를 확인합니다. 아래 사이즈를 누르면 해당 사이즈의 점수와 부위별 차이를 비교할 수 있습니다."
    else -> "분석 결과 저장하기" to "히스토리에 추가를 누르면 리포트를 저장합니다. 확인하기를 누르면 저장하지 않고 Fit Lab으로 돌아갑니다."
}
