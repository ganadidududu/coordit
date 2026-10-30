package com.inseong.coordit.data

import com.google.gson.JsonParser
import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.remote.CoorditApi
import com.inseong.coordit.data.repository.SessionRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

class SessionRepositoryTest {
    private lateinit var server: MockWebServer
    private lateinit var store: MemoryStore
    private lateinit var repository: SessionRepository
    private val saved = AuthSession("old-access", "old-refresh", AuthUser("user-1", "u@example.com"))
    private val authJson = """{"accessToken":"new-access","refreshToken":"new-refresh","user":{"id":"user-1","email":"u@example.com"}}"""

    @Before fun setup() {
        server = MockWebServer().apply { start() }
        store = MemoryStore()
        val api = Retrofit.Builder().baseUrl(server.url("/"))
            .addConverterFactory(GsonConverterFactory.create(CoorditJson.create())).build().create(CoorditApi::class.java)
        repository = SessionRepository(api, store)
    }
    @After fun tearDown() { server.shutdown() }

    @Test fun googleRequestAndPublicationMatchBackendContract() = runTest {
        server.enqueue(MockResponse().setBody(authJson))
        val session = repository.loginGoogle("provider-token", "raw-nonce")
        val request = server.takeRequest()
        assertEquals("/auth/google", request.path)
        assertEquals("POST", request.method)
        assertNull(request.getHeader("Authorization"))
        val body = JsonParser.parseString(request.body.readUtf8()).asJsonObject
        assertEquals("provider-token", body["idToken"].asString)
        assertEquals("raw-nonce", body["nonce"].asString)
        assertEquals(session, store.value)
        assertEquals(session, repository.session.value)
        assertFalse(session.toString().contains("new-access"))
    }
    @Test fun refreshInvalidationClearsOnlyRejectedCredentials() = runTest {
        store.value = saved
        server.enqueue(MockResponse().setResponseCode(401).setBody("{\"message\":\"invalid token\"}"))
        try { repository.restore(); fail("Expected rejection") } catch (error: HttpException) { assertEquals(401, error.code()) }
        assertNull(store.value)
        assertNull(repository.session.value)
    }
    @Test fun validGuestSessionRestoresWithoutCallingRefreshEndpoint() = runTest {
        val payload = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString("{\"exp\":${System.currentTimeMillis()/1000+3600}}".toByteArray())
        val guest = AuthSession("header.$payload.signature", "guest-refresh", AuthUser("guest-user", "", true))
        store.value = guest
        assertEquals(guest, repository.restore())
        assertEquals(0, server.requestCount)
        assertTrue(requireNotNull(repository.session.value).user.isAnonymous)
    }
    @Test fun serverContractFailureDoesNotDeleteSavedGuestIdentity() = runTest {
        store.value = saved.copy(user = AuthUser("guest-user", "", true))
        server.enqueue(MockResponse().setResponseCode(400).setBody("{\"message\":\"Auth user email is missing\"}"))
        try { repository.restore(); fail("Expected server contract failure") } catch (error: HttpException) { assertEquals(400,error.code()) }
        assertNotNull(store.value)
    }
    @Test fun transientFailureKeepsStoredSessionForRetry() = runTest {
        store.value = saved
        server.enqueue(MockResponse().setResponseCode(503))
        try { repository.restore(); fail("Expected server failure") } catch (error: HttpException) { assertEquals(503, error.code()) }
        assertEquals(saved, store.value)
        server.enqueue(MockResponse().setBody(authJson))
        val refreshed = repository.restore()
        assertEquals("new-refresh", refreshed?.refreshToken)
        assertEquals(refreshed, store.value)
    }
    @Test fun failedPersistenceNeverPublishesSession() = runTest {
        store.writeFailure = java.io.IOException("Disk unavailable")
        server.enqueue(MockResponse().setBody(authJson))
        try { repository.loginGoogle("token", "nonce"); fail("Expected disk failure") } catch (_: java.io.IOException) { }
        assertNull(repository.session.value)
    }
    @Test fun cancellationPropagatesAndKeepsStoredCredentials() = runTest {
        store.value = saved
        store.readFailure = CancellationException("cancelled")
        try { repository.restore(); fail("Expected cancellation") } catch (_: CancellationException) { }
        assertEquals(saved, store.value)
    }
    @Test fun onboardingUsesCamelCaseAndProfileDecodesSnakeCase() = runTest {
        server.enqueue(MockResponse().setBody(authJson))
        repository.loginGoogle("token", "nonce")
        server.takeRequest()
        server.enqueue(MockResponse().setBody("""{"onboardingComplete":true,"bodyMeasurementsSaved":true,"user":{"id":"user-1","email":"u@example.com","display_name":"코디","birth_date":"2000-01-01"}}"""))
        val response = repository.completeOnboarding(OnboardingRequest("코디", bodyMeasurements = OnboardingRequest.Measurements(170.0, 60.0), consents = mapOf("terms" to OnboardingRequest.Consent(true, "1.0"))))
        val request = server.takeRequest()
        assertEquals("/auth/onboarding", request.path)
        assertEquals("Bearer new-access", request.getHeader("Authorization"))
        val body = JsonParser.parseString(request.body.readUtf8()).asJsonObject
        assertEquals(170.0, body["bodyMeasurements"].asJsonObject["heightCm"].asDouble, 0.0)
        assertEquals("코디", response.user.displayName)
        assertEquals("2000-01-01", response.user.birthDate)
    }
    @Test fun malformedAuthenticationCannotReachStorage() = runTest {
        server.enqueue(MockResponse().setBody("{}"))
        try { repository.loginGoogle("token", "nonce"); fail("Expected malformed response failure") } catch (_: java.io.IOException) { }
        assertNull(store.value)
    }
    @Test fun invalidAuthFieldShapesNeverReachStorage() = runTest {
        val invalidPayloads = listOf(
            "null",
            "[]",
            """{"accessToken":null,"refreshToken":"r","user":{"id":"u","email":""}}""",
            """{"accessToken":"a","refreshToken":" ","user":{"id":"u","email":""}}""",
            """{"accessToken":"a","refreshToken":"r","user":null}""",
            """{"accessToken":"a","refreshToken":"r","user":{"email":""}}""",
            """{"accessToken":"a","refreshToken":"r","user":{"id":45,"email":""}}""",
            """{"accessToken":"a","refreshToken":"r","user":{"id":"u","email":null}}""",
            """{"accessToken":"a","refreshToken":"r","user":{"id":"u","email":false}}""",
        )
        for (payload in invalidPayloads) {
            server.enqueue(MockResponse().setBody(payload))
            try { repository.loginGoogle("token", "nonce"); fail("Expected invalid response rejection") } catch (_: java.io.IOException) { }
            assertNull(store.value)
            assertNull(repository.session.value)
        }
    }
    @Test fun emptyEmailIsAcceptedAsInIosContract() = runTest {
        server.enqueue(MockResponse().setBody("""{"accessToken":"a","refreshToken":"r","user":{"id":"u","email":""}}"""))
        assertEquals("", repository.loginGoogle("token", "nonce").user.email)
    }
    @Test fun anonymousMarkerSurvivesParsingAndEncryptedStoreSerialization() = runTest {
        val json = """{"accessToken":"a","refreshToken":"r","user":{"id":"guest-user","email":null,"isAnonymous":true}}"""
        server.enqueue(MockResponse().setBody(json))
        val guest = repository.loginGuest()
        assertTrue(guest.user.isAnonymous)
        assertEquals("", guest.user.email)
        val gson = CoorditJson.create()
        assertEquals(guest, gson.fromJson(gson.toJson(guest), AuthSession::class.java))
    }
    @Test fun myPageMutationsMatchBackendContractAndDeleteClearsSessionAfterSuccess() = runTest {
        server.enqueue(MockResponse().setBody(authJson))
        repository.loginGoogle("token", "nonce"); server.takeRequest()
        server.enqueue(MockResponse().setBody("""{"id":"user-1","email":"u@example.com","display_name":"새 이름"}"""))
        assertEquals("새 이름", repository.updateProfile(" 새 이름 ").displayName)
        server.takeRequest().also { request ->
            assertEquals("PATCH", request.method); assertEquals("/users/me", request.path)
            assertEquals("새 이름", JsonParser.parseString(request.body.readUtf8()).asJsonObject["displayName"].asString)
        }
        server.enqueue(MockResponse().setBody("""{"id":"body-1","height_cm":172.4,"weight_kg":61.8}"""))
        val measurement = repository.createBodyMeasurement(172.4, 61.8)
        assertEquals(172.4, measurement.heightCm!!, 0.0)
        server.takeRequest().also { request ->
            assertEquals("POST", request.method); assertEquals("/body-measurements", request.path)
            val body = JsonParser.parseString(request.body.readUtf8()).asJsonObject
            assertEquals(61.8, body["weightKg"].asDouble, 0.0)
            assertEquals("android-mypage", body["rawData"].asJsonObject["source"].asString)
        }
        server.enqueue(MockResponse().setResponseCode(204))
        repository.deleteAccount()
        assertEquals("DELETE", server.takeRequest().method)
        assertNull(store.value); assertNull(repository.session.value)
    }
    @Test fun feedbackConsentUsesAuthenticatedGetAndPatchWithoutChangingMarketing() = runTest {
        server.enqueue(MockResponse().setBody(authJson))
        repository.loginGoogle("token", "nonce"); server.takeRequest()
        val json = """{"consents":{"fit_data_improvement":{"accepted":true,"version":"2026-07-07","updatedAt":"2026-10-29T00:00:00Z"},"marketing":{"accepted":false,"version":"2026-07-07","updatedAt":null}}}"""
        server.enqueue(MockResponse().setBody(json))
        assertTrue(repository.loadFeedbackConsent())
        server.takeRequest().also {
            assertEquals("GET", it.method); assertEquals("/users/me/consents", it.path)
            assertEquals("Bearer new-access", it.getHeader("Authorization"))
        }
        val decoded = CoorditJson.create().fromJson(json, UserConsents::class.java)
        assertEquals("2026-07-07", decoded.consents.getValue("fit_data_improvement").version)
        assertEquals("2026-10-29T00:00:00Z", decoded.consents.getValue("fit_data_improvement").updatedAt)
        assertNull(decoded.consents.getValue("marketing").updatedAt)
        server.enqueue(MockResponse().setBody(json.replace("\"accepted\":true", "\"accepted\":false")))
        assertFalse(repository.updateFeedbackConsent(false))
        server.takeRequest().also {
            assertEquals("PATCH", it.method); assertEquals("/users/me/consents", it.path)
            assertEquals("Bearer new-access", it.getHeader("Authorization"))
            val body = JsonParser.parseString(it.body.readUtf8()).asJsonObject
            assertEquals(JsonParser.parseString("""{"consents":{"fit_data_improvement":{"accepted":false}}}"""), body)
        }
    }
    @Test fun missingFeedbackConsentIsNotInvented() = runTest {
        server.enqueue(MockResponse().setBody(authJson))
        repository.loginGoogle("token", "nonce"); server.takeRequest()
        listOf("""{"consents":{}}""", """{"consents":{"fit_data_improvement":{"accepted":null}}}""").forEach {
            server.enqueue(MockResponse().setBody(it))
            try { repository.loadFeedbackConsent(); fail("Expected missing consent rejection") } catch (_: java.io.IOException) { }
        }
    }
    private class MemoryStore : SessionStore {
        var value: AuthSession? = null
        var readFailure: Exception? = null
        var writeFailure: Exception? = null
        override suspend fun read(): AuthSession? { readFailure?.let { throw it }; return value }
        override suspend fun write(session: AuthSession) { writeFailure?.let { throw it }; value = session }
        override suspend fun clear() { value = null }
    }
}
