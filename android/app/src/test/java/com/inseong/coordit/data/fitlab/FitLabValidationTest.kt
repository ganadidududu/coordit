package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.home.HomeCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FitLabValidationTest {
    @Test fun validatesCompatibleMeasurementsAndNormalizedLabels() {
        val valid = FitLabDraft(
            productName = "셔츠",
            category = HomeCategory.Shirt,
            sizes = listOf(FitLabSizeDraft("m", "M", mapOf("shoulder_width" to 45.0))),
        )
        assertNull(valid.validationError())
        assertEquals(
            "사이즈명은 중복될 수 없어요.",
            valid.copy(sizes = valid.sizes + FitLabSizeDraft("full", "ｍ", mapOf("chest_width" to 54.0))).validationError(),
        )
        assertEquals(
            "카테고리에 맞는 측정값을 사이즈마다 하나 이상 입력해 주세요.",
            valid.copy(sizes = listOf(FitLabSizeDraft("bad", "M", mapOf("waist_width" to 40.0)))).validationError(),
        )
    }
}
