package com.inseong.coordit.data.fitlab.camera

import org.junit.Assert.*
import org.junit.Test

class GarmentMeasurementPolicyTest {
    @Test fun skirtHasNoRiseOrOutseam() {
        val dimensions = GarmentMeasurementPolicy.dimensions("skirt")
        assertEquals(listOf("waist_width", "hip_width", "total_length"), dimensions)
    }
    @Test fun allElevenCategoriesHaveCompleteMeasurementSchemas() {
        assertEquals(11, GarmentMeasurementPolicy.categories.size)
        GarmentMeasurementPolicy.categories.forEach { category ->
            assertEquals(if (category == "skirt") 3 else 4, GarmentMeasurementPolicy.dimensions(category).size)
        }
    }
    @Test fun spatialDistancesUseMetersAndRejectNonfiniteInput() {
        val cm = GarmentMeasurementPolicy.centimeters(listOf(0f, 0f, 0f), listOf(.3f, .4f, 0f))
        assertEquals(50.0, cm, .0001)
        assertFalse(GarmentMeasurementPolicy.plausible("chest_width", Double.NaN))
        assertFalse(GarmentMeasurementPolicy.plausible("rise", 1000.0))
    }
}
