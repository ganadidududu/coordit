package com.inseong.coordit.ui.components

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.navigationBarsIgnoringVisibility
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// The source auth/onboarding keep iOS safe areas, unlike the edge-to-edge splash.
// Reference iPhone 17 (402pt) has 62pt top and 34pt bottom safe-area insets.
@Composable
fun coorditReferenceTopInset(scale: Float): Dp = (62f * scale).dp.coerceAtLeast(
    WindowInsets.displayCutout.asPaddingValues().calculateTopPadding(),
)

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun coorditReferenceBottomInset(scale: Float): Dp = (34f * scale).dp.coerceAtLeast(
    WindowInsets.navigationBarsIgnoringVisibility.asPaddingValues().calculateBottomPadding(),
)
