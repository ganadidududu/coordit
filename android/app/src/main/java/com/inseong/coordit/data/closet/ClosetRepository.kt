package com.inseong.coordit.data.closet

import com.google.gson.annotations.SerializedName
import com.inseong.coordit.data.home.HomeCategory
import kotlinx.coroutines.CancellationException
import retrofit2.http.*
import java.net.URI

interface ClosetApi {
    @GET("clothing-items") suspend fun list(@Header("Authorization") auth: String): List<ClosetItemResponse>
    @GET("clothing-items/{id}") suspend fun item(@Header("Authorization") auth: String, @Path("id") id: String): ClosetItemResponse
    @GET("clothing-items/{id}/sizes") suspend fun sizes(@Header("Authorization") auth: String, @Path("id") id: String): List<ClosetSizeResponse>
    @POST("clothing-items/with-size") suspend fun create(@Header("Authorization") auth: String, @Body request: ClosetCreateRequest): ClosetCreateResponse
    @PATCH("clothing-items/{id}") suspend fun rename(@Header("Authorization") auth: String, @Path("id") id: String, @Body request: ClosetRenameRequest): ClosetItemResponse
    @DELETE("clothing-items/{id}") suspend fun delete(@Header("Authorization") auth: String, @Path("id") id: String)
    @POST("external-products/from-url") suspend fun prefill(@Header("Authorization") auth: String, @Body request: ClosetPrefillRequest): ClosetPrefillResponse
    @GET("fit/reference-profile/{kind}") suspend fun profile(@Header("Authorization") auth: String, @Path("kind") kind: String): ClosetReferenceProfile
    @GET("fit/closet-items/{id}/comparison") suspend fun comparison(@Header("Authorization") auth: String, @Path("id") id: String): ClosetComparison
}
data class ClosetRenameRequest(val name: String)
data class ClosetPrefillRequest(val url: String, val category: String)
data class ClosetItemResponse(val id: String, val name: String, val category: String, @SerializedName("size_label") val sizeLabel: String?) {
    fun item(): ClosetItem? = HomeCategory.entries.firstOrNull { it.wireName == category }?.let { ClosetItem(id, name, it, sizeLabel) }
}
data class ClosetSizeResponse(
    val id: String?, @SerializedName(value = "size_label", alternate = ["sizeLabel"]) val sizeLabel: String?,
    @SerializedName(value = "total_length", alternate = ["totalLength"]) val totalLength: Double?,
    @SerializedName(value = "shoulder_width", alternate = ["shoulderWidth"]) val shoulderWidth: Double?,
    @SerializedName(value = "chest_width", alternate = ["chestWidth"]) val chestWidth: Double?,
    @SerializedName(value = "sleeve_length", alternate = ["sleeveLength"]) val sleeveLength: Double?,
    @SerializedName(value = "waist_width", alternate = ["waistWidth"]) val waistWidth: Double?,
    @SerializedName(value = "hip_width", alternate = ["hipWidth"]) val hipWidth: Double?, val rise: Double?, val outseam: Double?,
) {
    fun row(index: Int) = ClosetSizeRow(id ?: "size-$index", sizeLabel ?: "등록 사이즈", mapOf("total_length" to totalLength, "shoulder_width" to shoulderWidth, "chest_width" to chestWidth, "sleeve_length" to sleeveLength, "waist_width" to waistWidth, "hip_width" to hipWidth, "rise" to rise, "outseam" to outseam).mapNotNull { (key, value) -> value?.takeIf { it.isFinite() && it > 0 }?.let { key to it } }.toMap())
}
data class ClosetCreateResponse(val clothingItem: ClosetItemResponse, val clothingSize: ClosetSizeResponse)
data class ClosetPrefillResponse(val productName: String?, val sizes: List<ClosetSizeResponse>, val category: String? = null)
data class ClosetPrefill(val name: String?, val rows: List<ClosetSizeRow>, val category: HomeCategory?)
class ClosetRepository(private val api: ClosetApi) {
    private fun auth(token: String): String { require(token.isNotBlank()) { "로그인이 필요해요." }; return "Bearer $token" }
    suspend fun profile(token: String, upper: Boolean): ClosetReferenceProfile = api.profile(auth(token), if (upper) "upper" else "lower")
    suspend fun load(token: String): List<ClosetItem> = api.list(auth(token)).mapNotNull { it.item() }
    suspend fun create(token: String, draft: ClosetDraft, key: String): ClosetDetail {
        val response = api.create(auth(token), draft.request(key))
        return ClosetDetail(requireNotNull(response.clothingItem.item()), listOf(response.clothingSize.row(0)))
    }
    suspend fun detail(token: String, id: String): ClosetDetail {
        val header = auth(token)
        val item = requireNotNull(api.item(header, id).item())
        val sizes = api.sizes(header, id).mapIndexed { index, size -> size.row(index) }
        var result = ClosetDetail(item, sizes)
        try { result = result.copy(profile = api.profile(header, if (item.category.upper) "upper" else "lower")) }
        catch (error: Exception) { if (error is CancellationException) throw error; result = result.copy(analysisError = "기준 핏 정보를 불러오지 못했어요.") }
        try { result = result.copy(comparison = api.comparison(header, id)) }
        catch (error: Exception) { if (error is CancellationException) throw error; result = result.copy(analysisError = "핏 비교를 불러오지 못했어요.") }
        return result
    }
    suspend fun rename(token: String, id: String, name: String): ClosetItem {
        require(name.trim().isNotEmpty()) { "의류 이름을 입력해 주세요." }
        return requireNotNull(api.rename(auth(token), id, ClosetRenameRequest(name.trim())).item())
    }
    suspend fun delete(token: String, id: String) = api.delete(auth(token), id)
    suspend fun prefill(token: String, draft: ClosetDraft): ClosetPrefill {
        val url = URI(draft.productLink.trim())
        require(url.scheme?.lowercase() in setOf("http", "https") && !url.host.isNullOrBlank()) { "HTTP 또는 HTTPS 상품 링크인지 확인해 주세요." }
        val response = api.prefill(auth(token), ClosetPrefillRequest(url.toString(), draft.category.wireName))
        val rows = response.sizes.mapIndexed { index, size -> size.row(index) }.filter { it.measurements.isNotEmpty() }
        require(rows.isNotEmpty()) { "사이즈표를 찾지 못했어요. 사진이나 직접 입력을 이용해 주세요." }
        return ClosetPrefill(response.productName, rows, HomeCategory.entries.firstOrNull { it.wireName == response.category })
    }
}
