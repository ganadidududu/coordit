package com.inseong.coordit.ui.theme

import androidx.compose.ui.text.intl.LocaleList
import androidx.compose.ui.text.style.LineBreak
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.inseong.coordit.R
import kotlin.math.roundToInt

@OptIn(ExperimentalTextApi::class)
object CoorditTypography {
    private val light = FontFamily(Font(R.font.gmarket_sans_light, FontWeight.Light))
    private val medium = FontFamily(Font(R.font.gmarket_sans_medium, FontWeight.Medium))
    private val bold = FontFamily(Font(R.font.gmarket_sans_bold, FontWeight.Bold))
    private val mona = FontFamily(Font(R.font.mona12_text_hk))
    private fun climate(year: Float) = FontFamily(Font(R.font.climate_crisis_kr,
        variationSettings = FontVariation.Settings(FontVariation.Setting("YEAR", year))))
    private val climate2010Family = climate(2012f)
    private val climate2019Family = climate(2019f)
    private val climate2030Family = climate(2028f)
    private fun style(family: FontFamily, size: Float, weight: FontWeight = FontWeight.Normal) = TextStyle(
        // UIFontMetrics rounds custom point sizes; confirmed by the iOS reference host.
        fontFamily = family, fontSize = size.roundToInt().coerceAtLeast(1).sp, fontWeight = weight,
        color = AppColors.ink, lineBreak = koreanParagraph, localeList = koreanLocale, platformStyle = PlatformTextStyle(includeFontPadding = false))
    val koreanParagraph = LineBreak.Paragraph.copy(wordBreak = LineBreak.WordBreak.Phrase)
    val koreanLocale = LocaleList("ko")
    fun gmarketLight(size: Float) = style(light, size, FontWeight.Light)
    fun gmarketMedium(size: Float) = style(medium, size, FontWeight.Medium)
    fun gmarketBold(size: Float) = style(bold, size, FontWeight.Bold)
    fun mona12(size: Float) = style(mona, size)
    fun climate2010(size: Float) = style(climate2010Family, size)
    fun climate2019(size: Float) = style(climate2019Family, size)
    fun climate2030(size: Float) = style(climate2030Family, size)
}
