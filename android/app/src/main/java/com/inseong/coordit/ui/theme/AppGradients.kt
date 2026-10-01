package com.inseong.coordit.ui.theme

import androidx.compose.ui.graphics.Color

object AppGradients {
    val topChrome = arrayOf(
        0.00f to AppColors.ink,
        0.20f to AppColors.ink,
        0.25f to Color(20, 32, 84),
        0.30f to Color(49, 60, 111),
        0.35f to Color(77, 87, 133),
        0.40f to Color(105, 114, 153),
        0.45f to Color(131, 139, 172),
        0.50f to Color(153, 160, 187),
        0.55f to Color(171, 177, 199),
        0.60f to Color(186, 191, 209),
        0.65f to Color(202, 206, 220),
        0.70f to Color(215, 217, 228),
        0.75f to Color(225, 228, 235),
        0.80f to Color(233, 234, 239),
        0.85f to Color(239, 241, 243),
        0.90f to Color(243, 244, 246),
        0.95f to Color(245, 246, 247),
        1.00f to AppColors.appBackground
    )
    val chromeEdgeHighlight = arrayOf(
        0.000f to AppColors.appBackground.copy(alpha = 0.43f),
        0.0125f to AppColors.appBackground.copy(alpha = 0.36f),
        0.025f to AppColors.appBackground.copy(alpha = 0.28f),
        0.030f to AppColors.appBackground.copy(alpha = 0.14f),
        0.050f to Color.Transparent,
        0.950f to Color.Transparent,
        0.970f to AppColors.appBackground.copy(alpha = 0.14f),
        0.975f to AppColors.appBackground.copy(alpha = 0.28f),
        0.9875f to AppColors.appBackground.copy(alpha = 0.36f),
        1.000f to AppColors.appBackground.copy(alpha = 0.43f)
    )
    val bottomChrome = arrayOf(
        0.000f to AppColors.appBackground,
        0.060f to Color(244, 245, 246),
        0.120f to Color(239, 240, 243),
        0.182f to Color(232, 234, 238),
        0.247f to Color(223, 225, 231),
        0.310f to Color(211, 214, 223),
        0.375f to Color(197, 201, 213),
        0.437f to Color(185, 189, 205),
        0.505f to Color(169, 173, 192),
        0.565f to Color(145, 151, 176),
        0.637f to Color(111, 119, 151),
        0.700f to Color(68, 79, 121),
        0.762f to Color(24, 36, 87),
        0.820f to Color(4, 16, 68),
        0.900f to AppColors.ink,
        1.000f to AppColors.ink
    )
    val bottomChromeContour = arrayOf(
        0.00f to Color.Transparent,
        0.05f to AppColors.ink.copy(alpha = 0.10f),
        0.13f to AppColors.ink.copy(alpha = 0.18f),
        0.31f to AppColors.ink.copy(alpha = 0.08f),
        0.50f to Color.Transparent,
        0.62f to AppColors.ink.copy(alpha = 0.05f),
        0.93f to AppColors.ink.copy(alpha = 0.10f),
        1.00f to Color.Transparent
    )
    val bottomChromeContourMask = arrayOf(
        0.00f to Color.Transparent,
        0.20f to Color.Black.copy(alpha = 0.35f),
        0.50f to Color.Black.copy(alpha = 0.80f),
        0.70f to Color.Black,
        1.00f to Color.Black
    )
}
