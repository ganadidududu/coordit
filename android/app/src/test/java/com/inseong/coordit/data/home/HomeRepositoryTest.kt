package com.inseong.coordit.data.home

import com.google.gson.Gson
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

class HomeRepositoryTest {
    @Test fun loadsSupportedGarmentsAndOnlyActiveExistingSelections() = runTest {
        val api = FakeHomeApi()
        val snapshot = HomeRepository(api).load("session")
        assertEquals(listOf("top", "bottom"), snapshot.items.map { it.id })
        assertEquals(setOf("top"), snapshot.selectedIds)
        assertTrue(api.authorizations.all { it == "Bearer session" })
    }

    @Test fun selectionPersistsAndDeselectsActiveReference() = runTest {
        val api = FakeHomeApi()
        val snapshot = HomeRepository(api).saveSelection("session", setOf("bottom"))
        assertEquals(setOf("bottom"), snapshot.selectedIds)
        assertEquals(listOf("ref-top"), api.deactivated)
        assertEquals("pants", api.created.single().category)
        assertEquals(100.0, api.created.single().preferenceScore, 0.0)
    }

    @Test fun rejectsStaleSelectionBeforeWrites() = runTest {
        val api = FakeHomeApi()
        val failure = runCatching { HomeRepository(api).saveSelection("session", setOf("deleted")) }.exceptionOrNull()
        assertTrue(failure is IllegalArgumentException)
        assertTrue(api.created.isEmpty())
        assertTrue(api.deactivated.isEmpty())
    }

    @Test fun wireContractUsesCamelCaseRequestAndSnakeCaseResponse() = runTest {
        val server = MockWebServer()
        try {
            server.enqueue(MockResponse().setBody("""{"id":"ref","clothing_item_id":"top","is_active":true}"""))
            val api = Retrofit.Builder().baseUrl(server.url("/")).addConverterFactory(GsonConverterFactory.create()).build().create(HomeApi::class.java)
            val reference = api.select("Bearer session", HomeReferenceRequest("top", "티셔츠", "tshirt"))
            assertEquals("top", reference.clothingItemId)
            assertTrue(reference.isActive)
            val request = server.takeRequest()
            assertEquals("/reference-clothing", request.path)
            assertEquals("Bearer session", request.getHeader("Authorization"))
            val body = Gson().fromJson(request.body.readUtf8(), com.google.gson.JsonObject::class.java)
            assertEquals("top", body["clothingItemId"].asString)
            assertTrue(body["isActive"].asBoolean)
            assertFalse(body.has("clothing_item_id"))
        } finally { server.shutdown() }
    }

    private class FakeHomeApi : HomeApi {
        val authorizations = mutableListOf<String>()
        val created = mutableListOf<HomeReferenceRequest>()
        val deactivated = mutableListOf<String>()
        val rows = mutableListOf(HomeReferenceResponse("ref-top", "top", true), HomeReferenceResponse("orphan", "missing", true))
        override suspend fun clothing(authorization: String): List<HomeClothingResponse> {
            authorizations += authorization
            return listOf(HomeClothingResponse("top", "티셔츠", "tshirt"), HomeClothingResponse("bottom", "팬츠", "pants"), HomeClothingResponse("other", "양말", "socks"))
        }
        override suspend fun references(authorization: String): List<HomeReferenceResponse> {
            authorizations += authorization
            return rows.toList()
        }
        override suspend fun select(authorization: String, request: HomeReferenceRequest): HomeReferenceResponse {
            created += request
            return HomeReferenceResponse("ref-${request.clothingItemId}", request.clothingItemId, true).also { rows += it }
        }
        override suspend fun deactivate(authorization: String, id: String): HomeReferenceResponse {
            deactivated += id
            val row = rows.first { it.id == id }.copy(isActive = false)
            rows.removeAll { it.id == id }
            rows += row
            return row
        }
    }
}
