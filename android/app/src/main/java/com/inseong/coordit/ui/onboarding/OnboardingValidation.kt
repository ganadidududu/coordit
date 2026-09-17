package com.inseong.coordit.ui.onboarding

import java.time.DateTimeException
import java.time.LocalDate

internal fun onboardingBirthDate(year: String, month: String, day: String, currentYear: Int = LocalDate.now().year): String? {
    val y = year.toIntOrNull() ?: return null
    val m = month.toIntOrNull() ?: return null
    val d = day.toIntOrNull() ?: return null
    if (y !in 1900..currentYear) return null
    return try { LocalDate.of(y, m, d).toString() } catch (_: DateTimeException) { null }
}

internal fun onboardingProfileError(name: String, year: String, month: String, day: String): String? {
    if (name.isBlank()) return "옷장 기록에 표시할 이름을 입력해 주세요."
    val parts = listOf(year, month, day)
    if (parts.any { it.isNotEmpty() } && parts.any { it.isEmpty() }) return "생일은 연·월·일을 모두 입력해 주세요."
    if (parts.all { it.isNotEmpty() } && onboardingBirthDate(year, month, day) == null) return "실제 생일을 확인해 주세요."
    return null
}

internal fun onboardingMeasurement(value: String): Double? = value.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 }
internal const val OnboardingConsentVersion = "2026-07-07"
