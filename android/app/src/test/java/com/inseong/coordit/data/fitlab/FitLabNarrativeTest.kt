package com.inseong.coordit.data.fitlab

import com.google.gson.Gson
import com.inseong.coordit.data.home.HomeCategory
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.Locale

class FitLabNarrativeTest {
    private data class Expected(val components: List<String>, val traits: List<String>, val shape: String, val fitConflict: Boolean, val stretchConflict: Boolean)
    private data class Case(val id: String, val category: String, val rows: List<Map<String, Double>>, val facts: Map<String, String>, val edited: Boolean, val expected: Expected)

    @Test fun sharedCompositionAndWholeTableDecisions() {
        // Given the same independently authored vectors used by iOS.
        val source = checkNotNull(javaClass.getResourceAsStream("/narrative-cases.json")).bufferedReader().use { it.readText() }
        val cases = Gson().fromJson(source, Array<Case>::class.java)
        val rendered = cases.associate { item ->
            val category = HomeCategory.entries.first { it.wireName == item.category }
            val facts = ProductFacts("테스트 상품", "https://shop.example/products/fixture", "2026-10-30T03:00:00.000Z", item.facts.toSortedMap().map { ProductFact(it.key, it.value) })
            val draft = FitLabDraft(source = FitLabSource.Url, category = category, productName = if (item.edited) "수정 상품" else "테스트 상품", productUrl = facts.sourceUrl, productFacts = facts,
                sizes = item.rows.mapIndexed { index, row -> FitLabSizeDraft("row-$index", if (index == 0) "M" else "L", row) })
            // When a fresh on-device analysis is computed.
            val analysis = FitLabNarrative(draft)
            // Then only justified semantic decisions are emitted; prose is not pinned.
            assertEquals(item.id, item.expected.components, analysis.components.map { it.fiberID })
            assertEquals(item.id, item.expected.traits, analysis.traitIDs)
            assertEquals(item.id, item.expected.shape, analysis.shape.name.lowercase(Locale.ROOT))
            assertEquals(item.id, item.expected.fitConflict, analysis.fitConflict)
            assertEquals(item.id, item.expected.stretchConflict, analysis.stretchConflict)
            item.id to analysis.paragraph
        }
        val output = File("build/reports/narrative-parity.json")
        output.parentFile.mkdirs()
        output.writeText(Gson().toJson(rendered))
    }

    @Test fun measurementEditsRecomputeShape() {
        // Given two wide/short shirt sizes.
        val draft = FitLabDraft(category = HomeCategory.Shirt, sizes = listOf(FitLabSizeDraft("m", "M", mapOf("chest_width" to 56.0, "total_length" to 70.0)), FitLabSizeDraft("l", "L", mapOf("chest_width" to 58.0, "total_length" to 72.0))))
        assertEquals(NarrativeShape.Boxy, FitLabNarrative(draft).shape)
        // When the user changes only the lengths.
        val edited = draft.copy(sizes = draft.sizes.map { it.copy(measurements = it.measurements + ("total_length" to (it.measurements.getValue("total_length") + 10))) })
        // Then a previous boxy interpretation cannot survive the edit.
        assertEquals(NarrativeShape.Unknown, FitLabNarrative(edited).shape)
    }
}
