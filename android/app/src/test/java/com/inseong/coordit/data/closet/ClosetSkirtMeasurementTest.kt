package com.inseong.coordit.data.closet

import com.inseong.coordit.data.home.HomeCategory
import org.junit.Assert.*
import org.junit.Test

class ClosetSkirtMeasurementTest {
    @Test fun skirtSavesWaistHipAndTotalLengthWithoutInventingRiseOrOutseam() {
        val draft = ClosetDraft(method = ClosetMethod.Manual, name = "skirt", category = HomeCategory.Skirt,
            measurement1 = "38", measurement2 = "50", measurement3 = "80")
        val request = draft.request("stable-retry-key")
        assertEquals(80.0, requireNotNull(request.size.totalLength), .0001)
        assertNull(request.size.rise)
        assertNull(request.size.outseam)
        assertEquals("stable-retry-key", request.idempotencyKey)
    }
}
