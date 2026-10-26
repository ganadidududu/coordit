package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.model.CoorditJson
import org.junit.Assert.*
import org.junit.Test

class FitLabScoreSelectionTest {
    private val gson = CoorditJson.create()
    private val recommendation = gson.fromJson("""
        {"fitAnalysisResultId":"analysis", "recommendedSize":"M", "fitScore":93.5,
         "fitLabel":"good_fit", "fitComment":"", "recommendationConfidence":"high",
         "diff":{"shoulder_width":0.5}, "partExplanations":[], "allSizeScores":[
           {"sizeLabel":"M", "fitScore":93.5},
           {"sizeLabel":"L", "fitScore":82,
            "measurementSubscores":{"shoulder_width":70},
            "semanticSubscores":{"silhouette":80},
            "semanticFacts":[{"measurement":"shoulder_width","reference":44.5,"product":47,"diff":2.5}]}
         ]}
    """.trimIndent(), FitLabRecommendation::class.java)

    @Test fun alternativeUsesItsServerScoresAndMeasurements() {
        val report = FitLabReportResponse(chartData = FitLabChartData(
            fitPointScores = listOf(FitLabFitPointScore("silhouette", "실루엣", 96.0)),
            measurementScores = listOf(FitLabMeasurementScore("shoulder_width", "어깨", 98.0, .5, "similar")),
        ))

        val selected = selectFitLabScore(recommendation, report, "L")

        assertFalse(selected.isRecommended)
        assertEquals(82.0, selected.fitScore, 0.0)
        assertEquals(80.0, selected.fitPointScores.single().score, 0.0)
        assertEquals(70.0, selected.measurementScores.single().score, 0.0)
        assertEquals(2.5, selected.comparisons.single().diff, 0.0)
    }

    @Test fun legacyAlternativeDoesNotReuseRecommendedScores() {
        val legacy = recommendation.copy(allSizeScores = listOf(FitLabSizeScore("L", 82.0)))
        val report = FitLabReportResponse(chartData = FitLabChartData(
            fitPointScores = listOf(FitLabFitPointScore("silhouette", "실루엣", 96.0)),
        ))

        val selected = selectFitLabScore(legacy, report, "L")

        assertEquals(82.0, selected.fitScore, 0.0)
        assertTrue(selected.fitPointScores.isEmpty())
        assertTrue(selected.measurementScores.isEmpty())
        assertTrue(selected.comparisons.isEmpty())
    }

    @Test fun savedRecommendationRetainsAlternativeMetadata() {
        val decoded = gson.fromJson(gson.toJson(recommendation), FitLabRecommendation::class.java)

        val selected = selectFitLabScore(decoded, null, "L")

        assertEquals(70.0, selected.measurementScores.single().score, 0.0)
        assertEquals(47.0, selected.comparisons.single().product, 0.0)
    }
}
