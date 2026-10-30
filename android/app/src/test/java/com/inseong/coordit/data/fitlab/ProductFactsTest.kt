package com.inseong.coordit.data.fitlab

import com.google.gson.Gson
import com.inseong.coordit.data.closet.ClosetPrefillResponse
import org.junit.Assert.*
import org.junit.Test

class ProductFactsTest {
    @Test fun conciseReportOnlyComparesSharedValidMeasurements() {
        val draft = FitLabDraft(sizes = listOf(FitLabSizeDraft("m", "M", mapOf("chest_width" to 56.0, "total_length" to 70.0)), FitLabSizeDraft("l", "L", mapOf("total_length" to 72.0, "shoulder_width" to Double.NaN))))
        val summary = FitLabProductReading(draft).conciseSizeSummary
        assertTrue(summary.contains("가슴 단면 56cm"))
        assertTrue(summary.contains("총장 +2cm"))
        assertFalse(summary.contains("가슴 단면 +"))
        assertFalse(summary.contains("NaN"))
    }

    @Test fun provenanceSurvivesSerializationButEditedProductsCannotUseIt() {
        val facts = ProductFacts("리넨 셔츠", "https://shop.example/product", "2026-10-30T03:00:00.000Z", listOf(ProductFact("material", "리넨 55%, 면 45%"), ProductFact("future-kind", "unknown")))
        val draft = FitLabDraft(source = FitLabSource.Url, productName = facts.productName, productUrl = facts.sourceUrl, productFacts = facts)
        val restored = Gson().fromJson(Gson().toJson(draft), FitLabDraft::class.java)
        assertEquals(facts, restored.productFacts)
        assertTrue(facts.appliesTo(restored))
        assertFalse(facts.appliesTo(draft.copy(productName = "다른 상품")))
        assertFalse(facts.appliesTo(draft.copy(productUrl = "https://shop.example/other")))
        assertFalse(facts.appliesTo(draft.copy(source = FitLabSource.Manual)))
        assertNull(facts.summary(listOf("fit", "future-kind")))
        assertNull(Gson().fromJson("""{"productName":"옛 상품","sizes":[]}""", ClosetPrefillResponse::class.java).productFacts)
    }
}
