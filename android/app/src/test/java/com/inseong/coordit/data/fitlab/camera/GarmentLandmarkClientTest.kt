package com.inseong.coordit.data.fitlab.camera

import org.junit.Assert.assertNull
import org.junit.Test

class GarmentLandmarkClientTest {
    @Test fun developmentModelsAndWrongCoordinateSystemsCannotReplaceExistingMeasurements() {
        val response = GarmentLandmarkClient.Response(1, "needs_calibration", "smoke-v1", "skirt",
            "upright_rgb_normalized_top_left", false, emptyList())
        assertNull(response.validatedEndpoints("skirt"))
        assertNull(response.copy(deploymentApproved = true, coordinateSystem = "sensor_pixels").validatedEndpoints("skirt"))
    }
}
