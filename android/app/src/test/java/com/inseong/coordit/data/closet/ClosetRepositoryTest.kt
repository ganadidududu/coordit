package com.inseong.coordit.data.closet

import com.google.gson.JsonParser
import com.inseong.coordit.data.home.HomeCategory
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

class ClosetRepositoryTest {
    private val draft = ClosetDraft(method = ClosetMethod.Manual, name = "  셔츠  ", measurement1 = "45", measurement2 = "54", measurement3 = "70", measurement4 = "61")
    @Test fun manualRequiresAllFourFinitePositiveMeasurements() {
        for (invalid in listOf("", "NaN", "Infinity", "0", "-1", "abc")) {
            try { draft.copy(measurement1 = invalid).request("key"); fail("Accepted $invalid") } catch (_: IllegalArgumentException) { }
        }
        assertEquals(45.0, draft.request("key").size.shoulderWidth!!, 0.0)
        val lower = draft.copy(category = HomeCategory.Pants).request("key").size
        assertEquals(45.0, lower.waistWidth!!, 0.0)
        assertNull(lower.shoulderWidth)
    }
    @Test fun photoRequiresChartEvenIfRowsRemain() {
        val row = ClosetSizeRow("M", "M", mapOf("chest_width" to 54.0))
        val photo = draft.copy(method = ClosetMethod.Photo, sizeRows = listOf(row), selectedSizeRowId = "M")
        try { photo.request("key"); fail("Missing chart accepted") } catch (_: IllegalArgumentException) { }
        assertEquals(54.0, photo.copy(hasSizeChartImage = true).request("key").size.chestWidth!!, 0.0)
    }
    @Test fun blankNameRejected() {
        try { draft.copy(name = "   ").request("key"); fail("Blank name accepted") } catch (_: IllegalArgumentException) { }
    }
    @Test fun extractedRowsRequireSelectionAndCategoryCompatibleMeasurements() {
        val row = ClosetSizeRow("m", "M", mapOf("waist_width" to 40.0))
        try { draft.copy(method = ClosetMethod.Photo, hasSizeChartImage = true, sizeRows = listOf(row)).request("key"); fail() } catch (_: IllegalArgumentException) { }
        try { draft.copy(method = ClosetMethod.Photo, hasSizeChartImage = true, sizeRows = listOf(row), selectedSizeRowId = "m").request("key"); fail() } catch (_: IllegalArgumentException) { }
    }
    @Test fun createUsesExactAtomicContractAndBearerToken() = runTest {
        MockWebServer().use { server ->
            server.start()
            val repository = ClosetRepository(Retrofit.Builder().baseUrl(server.url("/")).addConverterFactory(GsonConverterFactory.create()).build().create(ClosetApi::class.java))
            server.enqueue(MockResponse().setBody("""{"clothingItem":{"id":"item1","name":"셔츠","category":"tshirt","size_label":null},"clothingSize":{"id":"size1","shoulder_width":45,"chest_width":54,"total_length":70,"sleeve_length":61}}"""))
            assertEquals("item1", repository.create("token", draft, "stable-key").item.id)
            val request = server.takeRequest()
            assertEquals("/clothing-items/with-size", request.path)
            assertEquals("Bearer token", request.getHeader("Authorization"))
            val json = JsonParser.parseString(request.body.readUtf8()).asJsonObject
            assertEquals(setOf("item", "size", "idempotencyKey"), json.keySet())
            assertEquals("stable-key", json["idempotencyKey"].asString)
            assertEquals("셔츠", json["item"].asJsonObject["name"].asString)
            assertEquals(45.0, json["size"].asJsonObject["shoulder_width"].asDouble, 0.0)
            assertFalse(json["size"].asJsonObject.has("shoulderWidth"))
        }
    }
    @Test fun linkPrefillUsesCamelCaseAndLeavesEmptyExtractionAsError() = runTest {
        MockWebServer().use { server ->
            server.start()
            val repository = ClosetRepository(Retrofit.Builder().baseUrl(server.url("/")).addConverterFactory(GsonConverterFactory.create()).build().create(ClosetApi::class.java))
            server.enqueue(MockResponse().setBody("""{"productName":"상품","category":"shirt","sizes":[{"sizeLabel":"M","chestWidth":54,"totalLength":70}]}"""))
            val result = repository.prefill("token", draft.copy(productLink = "https://example.com/product"))
            assertEquals(HomeCategory.Shirt, result.category)
            assertEquals("상품", result.name)
            assertEquals(54.0, result.rows.single().measurements["chest_width"]!!, 0.0)
            assertEquals("/external-products/from-url", server.takeRequest().path)
            server.enqueue(MockResponse().setBody("""{"productName":"상품","category":"shirt","sizes":[]}"""))
            try { repository.prefill("token", draft.copy(productLink = "https://example.com/product")); fail() } catch (_: IllegalArgumentException) { }
        }
    }
}
