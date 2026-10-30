package com.inseong.coordit.ui.fitlab

internal fun isMeasurementText(text: String): Boolean = text.matches(Regex("[0-9]*([.,][0-9]*)?"))

internal fun measurementValue(text: String): Double? = if (isMeasurementText(text)) text.replace(',', '.').toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 } else null
