package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.home.HomeCategory
import org.junit.Assert.*
import org.junit.Test

class FitLabProductReadingTest {
    private fun row(label: String, width: Double? = 52.0, length: Double? = 68.0, lower: Boolean = false) = FitLabSizeDraft(label, label, buildMap {
        width?.let { put(if (lower) "waist_width" else "chest_width", it) }
        length?.let { put(if (lower) "outseam" else "total_length", it) }
    })
    private fun reading(vararg sizes: FitLabSizeDraft, category: HomeCategory = HomeCategory.Tshirt) = FitLabProductReading(FitLabDraft(category = category, sizes = sizes.toList()))

    @Test fun explainsWidthLengthAndApproximateCircumferenceFromTheSamePair() {
        val r = reading(row("M"), row("L", 54.0, 70.0))
        assertEquals("M보다 L의 가슴 단면이 2cm 넓어요.", r.headline)
        assertTrue(r.headlineDetail.contains("품과 기장이 함께"))
        assertTrue(r.sizeDifference.contains("둘레로는 약 4cm"))
        assertTrue(r.overview.contains("52~54cm"))
    }
    @Test fun selectsLargestAdjacentChangeWithoutSortingSizeLabels() {
        val r = reading(row("XS", 40.0), row("M", 41.0), row("L", 47.0))
        assertEquals("M → L 차이", r.sizeDifferenceTitle)
        assertTrue(r.headline.contains("6cm"))
    }
    @Test fun widthAndLengthMovingInOppositeDirectionsAreExplained() {
        val r = reading(row("M"), row("L", 54.0, 65.0))
        assertTrue(r.headlineDetail.contains("반대로"))
        assertTrue(r.sizeDifference.contains("3cm 더 짧아요"))
    }
    @Test fun equalWidthDoesNotClaimLargerFitWhenOnlyLengthChanges() {
        val r = reading(row("M"), row("L", 52.0, 70.0))
        assertEquals("두 사이즈의 가슴 너비는 같아요.", r.headline)
        assertTrue(r.headlineDetail.contains("가슴 쪽 여유는 같아요"))
    }
    @Test fun partialAndInvalidMeasurementsNeverProduceInventedValues() {
        val r = reading(row("M", Double.NaN, 68.0), row("L", -1.0, Double.POSITIVE_INFINITY))
        assertTrue(r.hasMissingMeasurements)
        assertEquals(listOf("total_length"), r.measurements.map { it.key })
        assertTrue(r.overview.contains("가슴 치수는 빠져"))
        assertTrue(r.sizeDifference.contains("치수가 부족"))
    }
    @Test fun singleSizeUsesReferenceAdvice() {
        val r = reading(row("FREE"))
        assertEquals("이 상품은 한 가지 사이즈로 나와요.", r.headline)
        assertTrue(r.sizeDifference.contains("다른 사이즈가 없어"))
    }
    @Test fun pantsUseWaistAndOutseam() {
        val r = reading(row("28", 36.0, 96.0, true), row("30", 38.0, 100.0, true), category = HomeCategory.Pants)
        assertTrue(r.headline.contains("허리 단면이 2cm"))
        assertTrue(r.sizeDifference.contains("총장은 4cm"))
        assertTrue(r.wearingContext.contains("밑위"))
    }
    @Test fun skirtUsesTotalLengthAndDoesNotRequireRise() {
        val sizes = listOf("S", "M").mapIndexed { i, label -> FitLabSizeDraft(label, label, mapOf("waist_width" to 34.0 + i, "hip_width" to 45.0 + i, "total_length" to 70.0 + i)) }
        val r = reading(*sizes.toTypedArray(), category = HomeCategory.Skirt)
        assertFalse(r.hasMissingMeasurements)
        assertEquals(listOf("waist_width", "hip_width", "total_length"), r.measurements.map { it.key })
        assertNull(FitLabDraft(productName = "스커트", category = HomeCategory.Skirt, sizes = sizes).validationError())
    }
}
