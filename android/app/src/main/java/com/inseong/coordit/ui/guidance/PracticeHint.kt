package com.inseong.coordit.ui.guidance

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.inseong.coordit.ui.components.*
import com.inseong.coordit.ui.theme.*

@Composable
fun PracticeHint(progress: String, title: String, message: String, onSkip: () -> Unit, scale: Float) {
    Column(Modifier.fillMaxWidth().background(GuidanceStyle.background, RoundedCornerShape((GuidanceStyle.radius * scale).dp)).padding((GuidanceStyle.inset * scale).dp).testTag("practice-hint"), verticalArrangement = Arrangement.spacedBy((6 * scale).dp)) {
        CoorditText("예시 따라하기", CoorditTypography.gmarketBold(GuidanceStyle.caption * scale).copy(color = GuidanceStyle.accent))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                CoorditText(progress, CoorditTypography.gmarketMedium(GuidanceStyle.caption * scale).copy(color = androidx.compose.ui.graphics.Color.White.copy(alpha = .85f)))
                CoorditText(title, CoorditTypography.gmarketBold(GuidanceStyle.title * scale).copy(color = androidx.compose.ui.graphics.Color.White))
            }
            Pressable(onSkip, Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp).testTag("practice-skip")) { CoorditText("건너뛰기", CoorditTypography.gmarketMedium(GuidanceStyle.caption * scale).copy(color = androidx.compose.ui.graphics.Color.White)) }
        }
        CoorditText(message, CoorditTypography.gmarketMedium(GuidanceStyle.body * scale).copy(color = androidx.compose.ui.graphics.Color.White))
    }
}
