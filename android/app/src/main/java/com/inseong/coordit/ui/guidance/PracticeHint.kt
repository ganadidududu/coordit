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
    Column(Modifier.fillMaxWidth().background(AppColors.closetField, RoundedCornerShape((10 * scale).dp)).padding(horizontal = (12 * scale).dp, vertical = (8 * scale).dp).testTag("practice-hint"), verticalArrangement = Arrangement.spacedBy((6 * scale).dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                CoorditText(progress, CoorditTypography.gmarketMedium(10 * scale).copy(color = AppColors.muted))
                CoorditText(title, CoorditTypography.gmarketBold(14 * scale))
            }
            Pressable(onSkip, Modifier.sizeIn(minWidth = 48.dp, minHeight = 48.dp).testTag("practice-skip")) { CoorditText("건너뛰기", CoorditTypography.gmarketMedium(11 * scale)) }
        }
        CoorditText(message, CoorditTypography.gmarketMedium(12 * scale))
    }
}
