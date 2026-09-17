package com.inseong.coordit.closet

import com.inseong.coordit.data.closet.*
import com.inseong.coordit.data.local.SessionStore
import com.inseong.coordit.data.model.*
import com.inseong.coordit.data.remote.CoorditApi
import kotlinx.coroutines.CompletableDeferred

internal class ClosetMemoryStore : SessionStore {
    private var value: AuthSession? = null
    override suspend fun read() = value
    override suspend fun write(session: AuthSession) { value = session }
    override suspend fun clear() { value = null }
}
internal class ClosetAuthApi : CoorditApi {
    private val profile = UserProfile("closet-test-user", "closet@example.invalid", "옷장테스트")
    override suspend fun health() = BackendHealth(true, "test")
    override suspend fun loginGoogle(request: SocialAuthRequest) = AuthSession("test-access", "test-refresh", AuthUser(profile.id, profile.email))
    override suspend fun loginApple(request: SocialAuthRequest): AuthSession = error("not used")
    override suspend fun refresh(request: RefreshAuthRequest): AuthSession = error("not used")
    override suspend fun me(authorization: String) = profile
    override suspend fun updateMe(authorization: String, request: UpdateProfileRequest) = profile.copy(displayName = request.displayName)
    override suspend fun deleteMe(authorization: String) = Unit
    override suspend fun onboardingStatus(authorization: String) = OnboardingStatus(true)
    override suspend fun completeOnboarding(authorization: String, request: OnboardingRequest): OnboardingCompletion = error("not used")
    override suspend fun bodyMeasurements(authorization: String) = emptyList<BodyMeasurement>()
    override suspend fun createBodyMeasurement(authorization: String, request: BodyMeasurementRequest) = BodyMeasurement("body", request.heightCm, request.weightKg)
    override suspend fun threadBalance(authorization: String) = ThreadBalanceResponse(0)
}
internal class ClosetFixture : ClosetApi {
    val items = mutableListOf<ClosetItemResponse>()
    val requests = mutableListOf<ClosetCreateRequest>()
    val savedSizes = mutableMapOf<String, ClosetSizeResponse>()
    var failCreate = true
    var failPrefill = true
    var saveGate: CompletableDeferred<Unit>? = null
    var deletes = 0
    fun size(id: String, label: String, extra: Double = 0.0) = ClosetSizeResponse(id, label, 70.0 + extra, 48.0 + extra, 54.0 + extra, 23.0 + extra, null, null, null, null)
    fun seed() {
        items.addAll(listOf(ClosetItemResponse("knit", "Relaxed Knit", "knit", "M"), ClosetItemResponse("jeans", "Wide Denim", "jeans", "M"), ClosetItemResponse("upper", "Oxford Shirt", "shirt", "M"), ClosetItemResponse("lower", "Black Slacks", "pants", "M")))
        savedSizes["upper"] = size("upper-size", "M")
        savedSizes["lower"] = ClosetSizeResponse("lower-size", "M", null, null, null, null, 40.0, 54.0, 31.0, 102.0)
    }
    override suspend fun list(auth: String) = items.toList()
    override suspend fun item(auth: String, id: String) = items.first { it.id == id }
    override suspend fun sizes(auth: String, id: String) = if (id == "upper") emptyList() else listOf(savedSizes.getValue(id))
    override suspend fun create(auth: String, request: ClosetCreateRequest): ClosetCreateResponse {
        requests.add(request)
        saveGate?.await()
        if (failCreate) { failCreate = false; throw java.io.IOException("fixture save failure") }
        val item = ClosetItemResponse("created-${requests.size}", request.item.name, request.item.category, request.item.sizeLabel)
        val s = request.size
        val size = ClosetSizeResponse("saved", s.sizeLabel, s.totalLength, s.shoulderWidth, s.chestWidth, s.sleeveLength, s.waistWidth, s.hipWidth, s.rise, s.outseam)
        items.add(item); savedSizes[item.id] = size
        return ClosetCreateResponse(item, size)
    }
    override suspend fun rename(auth: String, id: String, request: ClosetRenameRequest): ClosetItemResponse {
        val index = items.indexOfFirst { it.id == id }
        return items[index].copy(name = request.name).also { items[index] = it }
    }
    override suspend fun delete(auth: String, id: String) { deletes++; items.removeAll { it.id == id }; savedSizes.remove(id) }
    override suspend fun prefill(auth: String, request: ClosetPrefillRequest): ClosetPrefillResponse {
        if (failPrefill) { failPrefill = false; throw java.io.IOException("fixture prefill failure") }
        return ClosetPrefillResponse("링크로 불러온 티셔츠", listOf(size("M", "M"), size("L", "L", 2.0)), "tshirt")
    }
    override suspend fun profile(auth: String, kind: String) = ClosetReferenceProfile(kind, if (items.isEmpty()) 0 else 2, if (items.isEmpty()) emptyMap() else if (kind == "upper") mapOf("shoulder_width" to 48.0, "chest_width" to 54.0, "total_length" to 70.0, "sleeve_length" to 23.0) else mapOf("waist_width" to 40.0, "hip_width" to 54.0, "rise" to 31.0, "outseam" to 102.0), emptyMap(), "test")
    override suspend fun comparison(auth: String, id: String) = ClosetComparison("ready", if (item(auth, id).category == "pants") "lower" else "upper", 2, 94.0, 0.2, mapOf("shoulder_width" to -1.0, "chest_width" to 2.0, "total_length" to 1.5, "sleeve_length" to -0.5), null)
}
