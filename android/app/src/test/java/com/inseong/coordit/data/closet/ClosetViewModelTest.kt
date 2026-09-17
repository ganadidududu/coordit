package com.inseong.coordit.data.closet

import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.home.HomeCategory
import com.inseong.coordit.data.model.AuthSession
import com.inseong.coordit.data.remote.CoorditApi
import com.inseong.coordit.data.repository.SessionRepository
import com.inseong.coordit.ui.closet.ClosetViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.Assert.*
import org.junit.Test
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class ClosetViewModelTest {
    @Test fun retryKeepsKeyEditsChangeKeyAndLogoutClearsDraft() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            MockWebServer().use { server ->
                server.start()
                val retrofit = Retrofit.Builder().baseUrl(server.url("/")).addConverterFactory(GsonConverterFactory.create()).build()
                val sessions = SessionRepository(retrofit.create(CoorditApi::class.java), object : SessionStore {
                    override suspend fun read(): AuthSession? = null
                    override suspend fun write(session: AuthSession) {}
                    override suspend fun clear() {}
                })
                server.enqueue(MockResponse().setBody("""{"accessToken":"token","refreshToken":"refresh","user":{"id":"user1","email":"a@b.com"}}"""))
                sessions.loginGoogle("token", "nonce")
                val api = FailingApi(retrofit.create(ClosetApi::class.java))
                val model = ClosetViewModel(ClosetRepository(api), sessions)
                runCurrent()
                model.load(); runCurrent()
                assertEquals(3, model.state.value.profiles[true]?.referenceCount)
                assertEquals(4, model.state.value.profiles[false]?.referenceCount)
                model.openItem(model.state.value.items.single()); runCurrent()
                model.delete(); runCurrent()
                assertEquals(ClosetScreen.Overview, model.state.value.screen)
                assertTrue(model.state.value.items.isEmpty())
                assertEquals(2, model.state.value.profiles[true]?.referenceCount)
                assertEquals(4, model.state.value.profiles[false]?.referenceCount)
                assertEquals(listOf("upper", "lower"), api.profileCalls.takeLast(2))
                model.openItem(ClosetItem("second", "두 번째", HomeCategory.Tshirt)); runCurrent()
                api.failProfiles = true
                model.delete(); runCurrent()
                assertEquals(2, model.state.value.profiles[true]?.referenceCount)
                assertEquals(4, model.state.value.profiles[false]?.referenceCount)
                assertNotNull(model.state.value.error)
                assertEquals(listOf("upper", "lower"), api.profileCalls.takeLast(2))
                model.startAdd(); model.chooseMethod(ClosetMethod.Link)
                val extracted = ClosetSizeRow("M", "M", mapOf("chest_width" to 54.0))
                model.setSizeRows(listOf(extracted)); model.selectSize("M")
                model.editDraft { it.copy(productLink = "https://example.com/new") }
                assertTrue(model.state.value.draft.sizeRows.isEmpty())
                assertNull(model.state.value.draft.selectedSizeRowId)
                model.setSizeRows(listOf(extracted)); model.selectSize("M")
                model.editDraft { it.copy(category = HomeCategory.Shirt) }
                assertTrue(model.state.value.draft.sizeRows.isEmpty())
                assertNull(model.state.value.draft.selectedSizeRowId)
                model.editDraft { it.copy(name = "이전 상품") }
                model.prefill(); runCurrent()
                assertEquals("새 상품", model.state.value.draft.name)
                assertEquals(HomeCategory.Hoodie, model.state.value.draft.category)
                assertEquals(1, model.state.value.draft.sizeRows.size)
                assertNull(model.state.value.draft.selectedSizeRowId)
                model.selectSize(model.state.value.draft.sizeRows.single().id)
                model.back(); model.chooseMethod(ClosetMethod.Photo)
                assertTrue(model.state.value.draft.sizeRows.isEmpty())
                assertNull(model.state.value.draft.selectedSizeRowId)
                model.chooseMethod(ClosetMethod.Manual)
                model.editDraft { it.copy(name = "셔츠", measurement1 = "45", measurement2 = "54", measurement3 = "70", measurement4 = "61") }
                model.save(); runCurrent()
                assertEquals(ClosetScreen.Saving, model.state.value.screen)
                assertNotNull(model.state.value.error)
                model.save(); runCurrent()
                assertEquals(api.keys[0], api.keys[1])
                model.back()
                assertEquals(ClosetScreen.Manual, model.state.value.screen)
                model.editDraft { it.copy(name = "새 이름") }
                model.save(); runCurrent()
                assertNotEquals(api.keys[1], api.keys[2])
                model.back()
                api.slow = true
                model.save(); runCurrent()
                assertTrue(model.state.value.busy)
                val savingDraft = model.state.value.draft
                model.back(); model.editDraft { it.copy(name = "ignored") }; model.save()
                assertEquals(savingDraft, model.state.value.draft)
                assertEquals(4, api.keys.size)
                sessions.logout(); runCurrent()
                assertEquals(ClosetState(), model.state.value)
                api.release.complete(Unit); runCurrent()
                assertEquals(ClosetState(), model.state.value)
            }
        } finally { Dispatchers.resetMain() }
    }
    private class FailingApi(delegate: ClosetApi) : ClosetApi by delegate {
        val keys = mutableListOf<String>()
        var slow = false
        var deleted = false
        var failProfiles = false
        val profileCalls = mutableListOf<String>()
        override suspend fun list(auth: String) = listOf(ClosetItemResponse("first", "의류", "tshirt", null))
        override suspend fun item(auth: String, id: String) = ClosetItemResponse(id, "의류", "tshirt", null)
        override suspend fun sizes(auth: String, id: String) = emptyList<ClosetSizeResponse>()
        override suspend fun comparison(auth: String, id: String) = ClosetComparison("unavailable", "upper", 0, null, null, null, "no measurements")
        override suspend fun delete(auth: String, id: String) { deleted = true }
        override suspend fun profile(auth: String, kind: String): ClosetReferenceProfile {
            profileCalls += kind
            if (failProfiles) throw IOException("Profile unavailable")
            return ClosetReferenceProfile(kind, if (kind == "upper") { if (deleted) 2 else 3 } else 4, emptyMap(), emptyMap(), "test")
        }
        val release = CompletableDeferred<Unit>()
        override suspend fun prefill(auth: String, request: ClosetPrefillRequest) = ClosetPrefillResponse("새 상품", listOf(ClosetSizeResponse("m", "M", 70.0, 45.0, 54.0, 61.0, null, null, null, null)), "hoodie")
        override suspend fun create(auth: String, request: ClosetCreateRequest): ClosetCreateResponse {
            keys += request.idempotencyKey
            if (slow) {
                withContext(NonCancellable) { release.await() }
                return ClosetCreateResponse(ClosetItemResponse("stale", "stale", "tshirt", null), ClosetSizeResponse("s", null, 70.0, 45.0, 54.0, 61.0, null, null, null, null))
            }
            throw IOException("Ambiguous response")
        }
    }
}
