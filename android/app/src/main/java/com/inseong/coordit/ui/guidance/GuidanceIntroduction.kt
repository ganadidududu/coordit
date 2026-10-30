package com.inseong.coordit.ui.guidance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

internal object GuidanceStyle {
    val background = AppColors.ink
    val accent = AppColors.loadingSparkle
    const val inset = 16f
    const val radius = 12f
    const val title = 17f
    const val body = 15f
    const val caption = 12f
}

@Composable
fun GuidanceIntroduction(guide: UsageGuide, onStart: () -> Unit, onLater: () -> Unit) {
    val closet = guide == UsageGuide.Closet
    val steps = if (closet) listOf("내 옷 링크 불러오기", "보유한 사이즈 선택하기", "내 옷장에 등록하기")
        else listOf("상품 링크 불러오기", "무료 리포트 확인하기", "내 옷을 골라 비교하기")
    val maximumHeight = (LocalConfiguration.current.screenHeightDp * .9f).dp
    Dialog(onDismissRequest = onLater, properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false)) {
        Column(Modifier.padding(horizontal = 24.dp).widthIn(max = 402.dp).fillMaxWidth().heightIn(max = maximumHeight)
            .background(AppColors.panel, RoundedCornerShape(20.dp)).testTag("practice-introduction")) {
            Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                CoorditText("처음 이용 안내", CoorditTypography.gmarketBold(14f).copy(color = GuidanceStyle.accent),
                    Modifier.background(GuidanceStyle.background, RoundedCornerShape(30.dp)).padding(12.dp))
                CoorditText(if (closet) "옷장 등록, 예시로 함께 해볼까요?" else "핏랩, 예시로 함께 해볼까요?", CoorditTypography.gmarketBold(22f))
                CoorditText("처음에는 준비된 예시로 사용법을 익혀요.\n화면의 안내를 따라 직접 눌러보세요.", CoorditTypography.gmarketMedium(17f))
                Column(Modifier.fillMaxWidth().background(AppColors.field, RoundedCornerShape(GuidanceStyle.radius.dp)).padding(GuidanceStyle.inset.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    steps.forEachIndexed { index, step ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Box(Modifier.size(30.dp).background(AppColors.placeholder, CircleShape), contentAlignment = Alignment.Center) {
                                CoorditText("${index + 1}", CoorditTypography.gmarketBold(14f))
                            }
                            CoorditText(step, CoorditTypography.gmarketMedium(15f), Modifier.weight(1f).testTag("practice-intro-step-${index + 1}"))
                        }
                    }
                }
                CoorditText("실제 저장·실타래 사용 없이 연습해요.", CoorditTypography.gmarketMedium(15f))
            }
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                CoorditButton("안내 시작하기", onStart, Modifier.testTag("practice-intro-start"))
                CoorditButton("나중에 할게요", onLater, Modifier.testTag("practice-intro-later"), secondary = true)
                CoorditText("상단 ‘사용법’에서 언제든 다시 시작할 수 있어요.", CoorditTypography.gmarketMedium(12f))
            }
        }
    }
}
