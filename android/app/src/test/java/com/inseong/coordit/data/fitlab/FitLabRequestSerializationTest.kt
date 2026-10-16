package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.model.CoorditJson
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FitLabRequestSerializationTest {
    @Test
    fun reportBodyDecodesV7AndLegacyFields() {
        val json = CoorditJson.create()
        val current = json.fromJson(
            """{"title":"M 핏 리포트","garmentFitContext":"후드 핏 맥락","sizeTradeoff":"M과 L의 절충"}""",
            FitLabReportBody::class.java,
        )
        assertEquals("후드 핏 맥락", current.garmentFitContext)
        assertEquals("M과 L의 절충", current.sizeTradeoff)

        val legacy = json.fromJson("""{"title":"이전 리포트"}""", FitLabReportBody::class.java)
        assertNull(legacy.garmentFitContext)
        assertNull(legacy.sizeTradeoff)
    }

    @Test
    fun chartDataDecodesDeterministicFitPointScoresAndDefaultsLegacyPayloads() {
        val json = CoorditJson.create()
        val current = json.fromJson(
            """{"fitPointScores":[{"key":"silhouette","label":"실루엣","score":91},{"key":"mobility","label":"활동성","score":86}],"measurementScores":[{"measurement":"shoulder_width","label":"어깨","score":97.3,"diff":1,"status":"loose"}]}""",
            FitLabChartData::class.java,
        )
        assertEquals(listOf("silhouette", "mobility"), current.fitPointScores.map { it.key })
        assertEquals(listOf(91.0, 86.0), current.fitPointScores.map { it.score })
        assertEquals("shoulder_width", current.measurementScores.single().measurement)
        assertEquals(97.3, current.measurementScores.single().score, 0.001)
        assertEquals(1.0, current.measurementScores.single().diff, 0.001)

        val legacy = json.fromJson("{}", FitLabChartData::class.java)
        assertTrue(legacy.fitPointScores.isEmpty())
        assertTrue(legacy.measurementScores.isEmpty())
    }

    @Test
    fun sizeRequestUsesBackendSnakeCaseFields() {
        val json = CoorditJson.create().toJson(
            FitLabSizeRequest(
                sizeLabel = "M",
                parsingStatus = "confirmed",
                measurementSource = "manual",
                extractionConfidence = 0.72,
                shoulderWidth = 44.5,
                chestWidth = 52.0,
                totalLength = 68.0,
                sleeveLength = 21.0,
            ),
        )

        listOf("size_label", "parsing_status", "measurement_source", "extraction_confidence", "shoulder_width", "chest_width", "total_length", "sleeve_length")
            .forEach { assertTrue("missing $it in $json", json.contains("\"$it\"")) }
        assertFalse(json.contains("shoulderWidth"))
        assertFalse(json.contains("sizeLabel"))
    }
}
