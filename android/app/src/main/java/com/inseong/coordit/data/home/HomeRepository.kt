package com.inseong.coordit.data.home

import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

interface HomeApi {
    @GET("clothing-items")
    suspend fun clothing(@Header("Authorization") authorization: String): List<HomeClothingResponse>
    @GET("reference-clothing")
    suspend fun references(@Header("Authorization") authorization: String): List<HomeReferenceResponse>
    @POST("reference-clothing")
    suspend fun select(@Header("Authorization") authorization: String, @Body request: HomeReferenceRequest): HomeReferenceResponse
    @PATCH("reference-clothing/{id}/deactivate")
    suspend fun deactivate(@Header("Authorization") authorization: String, @Path("id") id: String): HomeReferenceResponse
}

data class HomeClothingResponse(val id: String?, val name: String?, val category: String?)
data class HomeReferenceResponse(
    val id: String?,
    @SerializedName("clothing_item_id") val clothingItemId: String?,
    @SerializedName("is_active") val isActive: Boolean = false,
)
data class HomeReferenceRequest(
    val clothingItemId: String,
    val nickname: String,
    val category: String,
    val fitType: String = "regular",
    val preferenceScore: Double = 100.0,
    val isActive: Boolean = true,
    val notes: String = "Selected from Android Home",
)

enum class HomeCategory(val wireName: String, val title: String, val upper: Boolean) {
    Tshirt("tshirt", "티셔츠", true), Shirt("shirt", "셔츠", true),
    Sweatshirt("sweatshirt", "스웨트셔츠", true), Hoodie("hoodie", "후드", true),
    Knit("knit", "니트", true), Jacket("jacket", "재킷", true), Coat("coat", "코트", true),
    Pants("pants", "팬츠", false), Jeans("jeans", "데님", false),
    Shorts("shorts", "쇼츠", false), Skirt("skirt", "스커트", false),
}
data class HomeGarment(val id: String, val name: String, val category: HomeCategory)
data class HomeSnapshot(val items: List<HomeGarment> = emptyList(), val selectedIds: Set<String> = emptySet())

class HomeRepository(private val api: HomeApi) {
    suspend fun load(token: String): HomeSnapshot = coroutineScope {
        val clothing = async { api.clothing(authorization(token)) }
        val references = async { api.references(authorization(token)) }
        snapshot(clothing.await(), references.await())
    }

    suspend fun saveSelection(token: String, ids: Set<String>): HomeSnapshot {
        val auth = authorization(token)
        val clothing = api.clothing(auth)
        val references = api.references(auth)
        val current = snapshot(clothing, references)
        require(ids.all { id -> current.items.any { it.id == id } }) { "선택한 의류가 변경되었어요. 새로고침 후 다시 선택해 주세요." }
        current.items.filter { it.id in ids }.forEach { item ->
            api.select(auth, HomeReferenceRequest(item.id, item.name, item.category.wireName))
        }
        references.filter { it.isActive && it.clothingItemId !in ids && current.items.any { item -> item.id == it.clothingItemId } }
            .forEach { reference -> api.deactivate(auth, requireNotNull(reference.id)) }
        return load(token)
    }

    private fun authorization(token: String): String {
        require(token.isNotBlank()) { "로그인이 필요해요." }
        return "Bearer $token"
    }

    private fun snapshot(clothing: List<HomeClothingResponse>, references: List<HomeReferenceResponse>): HomeSnapshot {
        val items = clothing.mapNotNull { row ->
            val category = HomeCategory.entries.firstOrNull { it.wireName == row.category } ?: return@mapNotNull null
            val id = requireNotNull(row.id).also { require(it.isNotBlank()) }
            HomeGarment(id, requireNotNull(row.name), category)
        }
        val validIds = items.map { it.id }.toSet()
        val selected = references.filter { it.isActive }.mapNotNull { it.clothingItemId }.toSet().intersect(validIds)
        return HomeSnapshot(items, selected)
    }
}
