package com.inseong.coordit.ui.guidance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

@Composable
fun UsageGuideSheet(guide: UsageGuide, onDismiss: () -> Unit, onExample: () -> Unit, firstUse: Boolean = false) {
    var skipConfirmation by remember { mutableStateOf(false) }
    fun close() { if (firstUse) skipConfirmation = true else onDismiss() }
    Dialog(onDismissRequest = ::close, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(.94f).background(AppColors.panel, RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)).testTag("usage-guide")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                CoorditText(guide.title, CoorditTypography.gmarketBold(22f), Modifier.weight(1f))
                Pressable(::close, Modifier.heightIn(min = 48.dp).testTag("usage-guide-close")) {
                    CoorditText(if (firstUse) "건너뛰기" else "닫기", CoorditTypography.gmarketMedium(12f))
                }
            }
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                if (firstUse) CoorditText("처음이라면 예시로 한 번 따라 해보세요. 핏랩과 옷장 사용법을 차례로 안내해드릴게요.", CoorditTypography.gmarketMedium(14f))
                CoorditText(guide.introduction, CoorditTypography.gmarketBold(15f), Modifier.fillMaxWidth().background(AppColors.closetField, RoundedCornerShape(12.dp)).padding(16.dp))
                guide.topics.forEach { topic ->
                    var expanded by rememberSaveable(guide, topic.id) { mutableStateOf(false) }
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Pressable({ expanded = !expanded }, Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("usage-topic-${topic.id}")) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                CoorditText(topic.title, CoorditTypography.gmarketBold(14f), Modifier.weight(1f))
                                CoorditText(if (expanded) "⌃" else "⌄", CoorditTypography.gmarketBold(16f))
                            }
                        }
                        if (expanded) CoorditText(topic.body, CoorditTypography.gmarketMedium(13f))
                        Box(Modifier.fillMaxWidth().height(1.dp).background(AppColors.line))
                    }
                }
                Spacer(Modifier.height(12.dp))
            }
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (guide == UsageGuide.References) {
                    CoorditButton("비교로 돌아가기", onDismiss, Modifier.testTag("usage-guide-return"))
                } else {
                    CoorditButton("링크 예시로 따라하기", onExample, Modifier.testTag("usage-guide-example"))
                    CoorditText("실타래 차감이나 저장 없이 체험해요.", CoorditTypography.gmarketMedium(11f).copy(color = AppColors.muted))
                }
            }
        }
    }
    if (skipConfirmation) Dialog(onDismissRequest = { skipConfirmation = false }) {
        Column(Modifier.background(AppColors.panel, RoundedCornerShape(14.dp)).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            CoorditText("처음이라면 따라 해보는 걸 추천해요", CoorditTypography.gmarketBold(18f))
            CoorditText("예시를 한 번 해보면 등록과 비교 흐름을 익힐 수 있어요. 나중에 사용법에서 다시 시작할 수도 있어요.", CoorditTypography.gmarketMedium(13f))
            CoorditButton("따라 해볼게요", { skipConfirmation = false; onExample() }, Modifier.testTag("usage-guide-skip-start-example"))
            CoorditButton("이번에는 건너뛰기", { skipConfirmation = false; onDismiss() }, secondary = true)
        }
    }
}
