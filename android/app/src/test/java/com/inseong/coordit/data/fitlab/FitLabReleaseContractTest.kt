package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.model.CoorditJson
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

class FitLabReleaseContractTest {
    @Test fun automaticCategoryIsOmittedAndManualOverrideIsSent() = runTest {
        MockWebServer().use { server ->
            server.start()
            val repository = repository(server)
            repeat(2) { server.enqueue(MockResponse().setBody("""{"productName":"셔츠","category":"shirt","sizes":[],"brand":"Coordit","mallName":"shop.example"}""")) }
            val result = repository.prefill("token", "https://shop.example/shirt", null)
            val automatic = server.takeRequest()
            assertFalse(automatic.body.readUtf8().contains("category"))
            assertEquals("Bearer token", automatic.getHeader("Authorization"))
            assertEquals("Coordit", result.brand)
            assertEquals("shop.example", result.mallName)
            repository.prefill("token", "https://shop.example/shirt", "jacket")
            assertTrue(server.takeRequest().body.readUtf8().contains("\"category\":\"jacket\""))
        }
    }

    @Test fun referencePickerRetainsCompatibleUpperCategoriesAndHidesInactiveOrLower() = runTest {
        MockWebServer().use { server ->
            server.start()
            server.enqueue(MockResponse().setBody("""[
                {"id":"shirt","clothing_item_id":"1","nickname":"셔츠","category":"shirt","is_active":true},
                {"id":"tee","clothing_item_id":"2","nickname":"반팔","category":"tshirt","is_active":true},
                {"id":"pants","clothing_item_id":"3","category":"pants","is_active":true},
                {"id":"inactive","clothing_item_id":"4","category":"shirt","is_active":false}
            ]"""))
            assertEquals(listOf("shirt", "tee"), repository(server).references("token", "shirt").map { it.id })
        }
    }

    private fun repository(server: MockWebServer) = FitLabRepository(Retrofit.Builder().baseUrl(server.url("/"))
        .addConverterFactory(GsonConverterFactory.create(CoorditJson.create())).build().create(FitLabApi::class.java))
}
