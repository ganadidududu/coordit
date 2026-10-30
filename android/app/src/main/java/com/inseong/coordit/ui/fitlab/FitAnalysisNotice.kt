package com.inseong.coordit.ui.fitlab

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.inseong.coordit.data.fitlab.FitLabNotice
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

@Composable
fun FitAnalysisNotice(notice: FitLabNotice, reduceMotion: Boolean, onDismiss: () -> Unit, onOpen: () -> Unit, modifier: Modifier = Modifier) {
    var drag by remember(notice) { mutableFloatStateOf(0f) }
    val offset by animateFloatAsState(if (reduceMotion) 0f else drag, label = "fit-notice-drag")
    val message = when (notice) {
        FitLabNotice.Running -> "핏 분석 중이에요. 다른 탭을 이용해도 계속 진행돼요."
        FitLabNotice.Completed -> "핏 분석이 완료됐어요. 눌러서 리포트를 확인하세요."
        FitLabNotice.Failed -> "핏 분석을 완료하지 못했어요. 눌러서 다시 시도하세요."
    }
    Row(modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp)
        .graphicsLayer { translationY = offset }
        .pointerInput(notice) {
            detectVerticalDragGestures(
                onVerticalDrag = { change, amount -> change.consume(); drag = (drag + amount).coerceAtMost(0f) },
                onDragEnd = { if (drag < -24.dp.toPx()) onDismiss() else drag = 0f },
                onDragCancel = { drag = 0f },
            )
        }
        .background(AppColors.ink, ContinuousRoundedShape(10.dp))
        .semantics {
            liveRegion = LiveRegionMode.Polite
            customActions = listOf(CustomAccessibilityAction("알림 닫기") { onDismiss(); true })
        }.testTag("fit-analysis-notice-${notice.name.lowercase()}"), verticalAlignment = Alignment.CenterVertically) {
        Pressable(onOpen, Modifier.weight(1f).heightIn(min = 56.dp).padding(12.dp)) {
            CoorditText(message, CoorditTypography.gmarketMedium(12f).copy(color = Color.White))
        }
        Pressable(onDismiss, Modifier.size(48.dp).semantics { contentDescription = "알림 닫기" }.testTag("fit-analysis-notice-dismiss")) {
            CoorditText("×", CoorditTypography.gmarketBold(22f).copy(color = Color.White))
        }
    }
}
