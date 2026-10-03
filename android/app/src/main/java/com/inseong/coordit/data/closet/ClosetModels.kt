package com.inseong.coordit.data.closet

import com.google.gson.annotations.SerializedName
import com.inseong.coordit.data.home.HomeCategory

enum class ClosetMethod { Manual, Link, Photo }
enum class ClosetScreen { Overview, Method, Manual, Link, Photo, Saving, Detail }
data class ClosetSizeRow(val id: String, val label: String, val measurements: Map<String, Double>)
data class ClosetItem(val id: String, val name: String, val category: HomeCategory, val sizeLabel: String? = null)
data class ClosetDraft(
    val method: ClosetMethod? = null,
    val name: String = "",
    val category: HomeCategory = HomeCategory.Tshirt,
    val productLink: String = "",
    val measurement1: String = "",
    val measurement2: String = "",
    val measurement3: String = "",
    val measurement4: String = "",
    val sizeRows: List<ClosetSizeRow> = emptyList(),
    val selectedSizeRowId: String? = null,
    val hasGarmentImage: Boolean = false,
    val hasSizeChartImage: Boolean = false,
) {
    val selectedSizeRow get() = sizeRows.firstOrNull { it.id == selectedSizeRowId }
    val measurementKeys get() = if (category.upper) listOf("shoulder_width", "chest_width", "total_length", "sleeve_length") else listOf("waist_width", "hip_width", "rise", "outseam")
    fun measurements(): Map<String, Double> {
        if (method != ClosetMethod.Manual) {
            val row = requireNotNull(selectedSizeRow) { "사이즈 행을 선택해 주세요." }
            require(row.measurements.isNotEmpty() && row.measurements.values.all { it.isFinite() && it > 0 }) { "유효한 실측값을 확인해 주세요." }
            require(row.measurements.keys.any { it in measurementKeys }) { "선택한 카테고리의 실측값을 확인해 주세요." }
            return row.measurements
        }
        val values = listOf(measurement1, measurement2, measurement3, measurement4).map {
            requireNotNull(it.trim().toDoubleOrNull()?.takeIf { value -> value.isFinite() && value > 0 }) { "네 가지 실측값을 양수로 입력해 주세요." }
        }
        return measurementKeys.zip(values).toMap()
    }
    fun request(key: String): ClosetCreateRequest {
        require(method != null) { "등록 방법을 선택해 주세요." }
        require(method != ClosetMethod.Photo || hasSizeChartImage) { "사이즈표 사진을 선택해 주세요." }
        require(name.trim().isNotEmpty()) { "의류 이름을 입력해 주세요." }
        val values = measurements()
        val source = method.name.lowercase()
        val metadata = buildMap {
            put("source", "android-closet-add"); put("method", source)
            if (productLink.isNotBlank()) put("productUrl", productLink.trim())
            if (hasGarmentImage) put("hasGarmentImage", "true")
            if (hasSizeChartImage) put("hasSizeChartImage", "true")
        }
        return ClosetCreateRequest(ClosetCreateItem(name.trim(), category.wireName, sizeLabel = selectedSizeRow?.label, rawProductData = metadata), ClosetSizeRequest(selectedSizeRow?.label, mapOf("source" to source), values["total_length"], values["shoulder_width"], values["chest_width"], values["sleeve_length"], values["waist_width"], values["hip_width"], values["rise"], values["outseam"]), key)
    }
}
data class ClosetCreateItem(val name: String, val category: String, val fitType: String = "regular", val sizeLabel: String?, val rawProductData: Map<String, String>)
data class ClosetCreateRequest(val item: ClosetCreateItem, val size: ClosetSizeRequest, val idempotencyKey: String)
data class ClosetSizeRequest(
    val sizeLabel: String?, val rawMeasurements: Map<String, String>,
    @SerializedName("total_length") val totalLength: Double?,
    @SerializedName("shoulder_width") val shoulderWidth: Double?,
    @SerializedName("chest_width") val chestWidth: Double?,
    @SerializedName("sleeve_length") val sleeveLength: Double?,
    @SerializedName("waist_width") val waistWidth: Double?,
    @SerializedName("hip_width") val hipWidth: Double?, val rise: Double?, val outseam: Double?,
)
data class ClosetReferenceProfile(val garmentKind: String, val referenceCount: Int, val measurements: Map<String, Double?>, val sampleCounts: Map<String, Int>, val strategy: String)
data class ClosetComparison(val status: String, val garmentKind: String, val referenceCount: Int, val fitScore: Double?, val bestFitGap: Double?, val diff: Map<String, Double?>?, val reason: String?)
data class ClosetDetail(val item: ClosetItem, val sizes: List<ClosetSizeRow> = emptyList(), val profile: ClosetReferenceProfile? = null, val comparison: ClosetComparison? = null, val analysisError: String? = null)
data class ClosetState(val screen: ClosetScreen = ClosetScreen.Overview, val profiles: Map<Boolean, ClosetReferenceProfile> = emptyMap(), val items: List<ClosetItem> = emptyList(), val draft: ClosetDraft = ClosetDraft(), val detail: ClosetDetail? = null, val loading: Boolean = false, val busy: Boolean = false, val error: String? = null)
