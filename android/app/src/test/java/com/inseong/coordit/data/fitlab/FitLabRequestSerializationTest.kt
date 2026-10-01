package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.model.CoorditJson
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FitLabRequestSerializationTest {
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
