package com.inseong.coordit.ui.fitlab

import org.junit.Assert.*
import org.junit.Test

class MeasurementInputTest {
    @Test fun trailingDecimalRemainsEditable() {
        var text = ""
        listOf("45", "45.", "45.5").forEach { edit ->
            if (isMeasurementText(edit)) text = edit
            assertEquals(edit, text)
        }
        assertEquals(45.0, measurementValue("45.")!!, 0.0)
        assertEquals(45.5, measurementValue(text)!!, 0.0)
    }
    @Test fun commaDecimalIsAccepted() {
        assertTrue(isMeasurementText("45,"))
        assertTrue(isMeasurementText("45,5"))
        assertEquals(45.5, measurementValue("45,5")!!, 0.0)
    }
    @Test fun nonNumericEditsAreRejected() {
        listOf("abc", "-1", "4a5", "45..5", "45,5.2", "1e2", "NaN", "Infinity").forEach {
            assertFalse(it, isMeasurementText(it))
            assertNull(measurementValue(it))
        }
    }
    @Test fun emptyAndZeroTextRemainEditableButHaveNoMeasurement() {
        listOf("", "0", ".", ",", "0.0").forEach {
            assertTrue(it, isMeasurementText(it))
            assertNull(measurementValue(it))
        }
    }
    @Test fun overflowingValueIsNotReported() { assertNull(measurementValue("9".repeat(400))) }
}
