package com.inseong.coordit.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import com.inseong.coordit.ui.theme.CoorditTypography

@Composable
fun ExampleNotice(scale: Float) {
    CoorditText("예시 체험 · 실제 저장이나 실타래 사용 없이 흐름을 확인해요.", CoorditTypography.gmarketMedium(12 * scale), Modifier.testTag("tutorial-example-notice"))
}
