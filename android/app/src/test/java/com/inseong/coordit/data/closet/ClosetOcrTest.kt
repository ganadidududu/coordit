package com.inseong.coordit.data.closet

import org.junit.Assert.*
import org.junit.Test

class ClosetOcrTest {
    private fun row(y: Float, vararg cells: String) = cells.mapIndexed { index, text -> OcrCell(text, index * 100f, y, 40f, 18f) }
    @Test fun horizontalKoreanTableRetainsActualSizesAndDecimals() {
        val cells = row(0f, "사이즈", "어깨", "가슴단면", "총장") + row(40f, "M", "42.5", "50", "66") + row(80f, "L", "44", "52,5", "68")
        val result = ClosetOcr.parse(cells, true)
        assertEquals(listOf("M", "L"), result.map { it.label })
        assertEquals(42.5, result[0].measurements.getValue("shoulder_width"), .001)
        assertEquals(52.5, result[1].measurements.getValue("chest_width"), .001)
    }
    @Test fun verticalLowerChartMapsLengthToOutseam() {
        val cells = row(0f, "SIZE", "28", "30") + row(40f, "허리", "36", "38") + row(80f, "총장", "100", "102")
        val result = ClosetOcr.parse(cells, false)
        assertEquals(listOf("28", "30"), result.map { it.label })
        assertEquals(mapOf("waist_width" to 36.0, "outseam" to 100.0), result[0].measurements)
    }
    @Test fun missingValueDoesNotShiftOtherColumns() {
        val cells = row(0f, "size", "어깨", "가슴", "총장") + row(40f, "S", "-", "48", "64")
        assertEquals(mapOf("chest_width" to 48.0, "total_length" to 64.0), ClosetOcr.parse(cells, true).single().measurements)
    }
    @Test fun rejectsRangesAndValuesWithUnrecognizedUnits() {
        val cells = row(0f, "size", "어깨", "가슴", "총장") + row(40f, "S", "40-42", "20in", "64")
        assertTrue(ClosetOcr.parse(cells, true).isEmpty())
    }
    @Test fun rejectsHeaderlessAndWrongCategoryCharts() {
        assertTrue(ClosetOcr.parse(row(0f, "S", "42", "50", "66"), true).isEmpty())
        assertTrue(ClosetOcr.parse(row(0f, "size", "어깨", "가슴") + row(40f, "S", "42", "50"), false).isEmpty())
    }
    @Test fun rejectsDuplicateMeasurementColumns() {
        assertTrue(ClosetOcr.parse(row(0f, "size", "가슴", "가슴단면") + row(40f, "M", "44", "88"), true).isEmpty())
    }
    @Test fun duplicateSizesRequireManualConfirmation() {
        val cells = row(0f, "size", "어깨", "가슴") + row(40f, "M", "42", "50") + row(80f, "M", "43", "51")
        assertTrue(ClosetOcr.parse(cells, true).isEmpty())
    }
    @Test fun ambiguousAlignmentDoesNotFabricateValues() {
        val cells = row(0f, "size", "어깨", "가슴") + listOf(OcrCell("M", 0f, 40f, 40f, 18f), OcrCell("42", 150f, 40f, 40f, 18f))
        assertTrue(ClosetOcr.parse(cells, true).isEmpty())
    }
}
