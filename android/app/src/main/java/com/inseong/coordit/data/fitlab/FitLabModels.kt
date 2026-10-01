package com.inseong.coordit.data.fitlab

import com.google.gson.annotations.SerializedName
import com.inseong.coordit.data.home.HomeCategory
import java.text.Normalizer
import java.util.Locale

enum class FitLabSource { Manual, Ocr, Url }
enum class FitLabScreen { Sources, Manual, Ocr, Url, Review, References, Loading, Result, HistoryDetail }
enum class FitLabStep { Idle, References, Product, Sizes, Recommendation, Report, Complete }

data class FitLabSizeDraft(
    val id: String,
    val label: String = "",
    val measurements: Map<String, Double> = emptyMap(),
)

data class FitLabDraft(
    val source: FitLabSource = FitLabSource.Manual,
    val category: HomeCategory = HomeCategory.Tshirt,
    val productName: String = "",
    val brand: String = "",
    val productUrl: String = "",
    val sizes: List<FitLabSizeDraft> = listOf(FitLabSizeDraft("size-1")),
    val selectedReferenceIds: Set<String> = emptySet(),
) {
    val upper get() = category.upper
    fun validationError(): String? {
        if (productName.isBlank()) return "상품명을 입력해 주세요."
        if (sizes.isEmpty()) return "사이즈 행을 하나 이상 추가해 주세요."
        val labels = sizes.map { Normalizer.normalize(it.label.trim(), Normalizer.Form.NFKC).lowercase(Locale.ROOT) }
        if (labels.any(String::isBlank)) return "모든 사이즈명을 입력해 주세요."
        if (labels.distinct().size != labels.size) return "사이즈명은 중복될 수 없어요."
        val allowed = measurementKeys(upper).toSet()
        if (sizes.any { row -> row.measurements.isEmpty() || row.measurements.any { (key, value) -> key !in allowed || !value.isFinite() || value <= 0 } }) {
            return "카테고리에 맞는 측정값을 사이즈마다 하나 이상 입력해 주세요."
        }
        return null
    }
}

data class FitLabReference(
    val id: String,
    @SerializedName("clothing_item_id") val clothingItemId: String,
    val nickname: String?,
    val category: String,
    @SerializedName("is_active") val isActive: Boolean,
)

data class FitLabProductRequest(val productName: String, val brand: String?, val mallName: String? = null, val productUrl: String?, val category: String, val fitType: String = "regular")
data class FitLabProductResponse(val id: String, @SerializedName("product_name") val productName: String? = null, val category: String? = null)
data class FitLabSizeRequest(
    @SerializedName("size_label") val sizeLabel: String,
    @SerializedName("parsing_status") val parsingStatus: String?,
    @SerializedName("measurement_source") val measurementSource: String,
    @SerializedName("extraction_confidence") val extractionConfidence: Double? = null,
    @SerializedName("shoulder_width") val shoulderWidth: Double? = null,
    @SerializedName("chest_width") val chestWidth: Double? = null,
    @SerializedName("total_length") val totalLength: Double? = null,
    @SerializedName("sleeve_length") val sleeveLength: Double? = null,
    @SerializedName("waist_width") val waistWidth: Double? = null,
    @SerializedName("hip_width") val hipWidth: Double? = null,
    val rise: Double? = null,
    val outseam: Double? = null,
)
data class FitLabSizeResponse(val id: String, @SerializedName("size_label") val sizeLabel: String? = null)
data class FitLabRecommendRequest(val referenceClothingIds: List<String>, val externalProductId: String, val idempotencyKey: String)
data class FitLabSizeScore(val sizeLabel: String, val fitScore: Double, val fitLabel: String? = null)
data class FitLabRecommendation(
    val fitAnalysisResultId: String,
    val recommendedSize: String,
    val fitScore: Double,
    val fitLabel: String,
    val fitComment: String,
    val recommendationConfidence: String,
    val diff: Map<String, Double> = emptyMap(),
    val allSizeScores: List<FitLabSizeScore> = emptyList(),
    val partExplanations: List<String> = emptyList(),
    val availableThreads: Int? = null,
)
data class FitLabReportRequest(val idempotencyKey: String, val selectedSizeLabel: String?, val style: String? = null, val includeDebug: Boolean = false)
data class FitLabMeasurementAnalysis(val measurement: String, val text: String)
data class FitLabReportBody(
    val title: String = "핏 리포트",
    val summary: String = "",
    val recommendationReason: String? = null,
    val fitDnaSummary: String? = null,
    val measurementAnalysis: List<FitLabMeasurementAnalysis> = emptyList(),
    val cautions: List<String> = emptyList(),
    val nextActions: List<String> = emptyList(),
)
data class FitLabComparison(val measurement: String, val label: String, val ideal: Double, val product: Double, val diff: Double, val status: String?)
data class FitLabDifference(val measurement: String, val label: String, val diff: Double, val direction: String?, val status: String?)
data class FitLabChartData(
    val idealVsProduct: List<FitLabComparison> = emptyList(),
    val differenceBar: List<FitLabDifference> = emptyList(),
    val sizeScoreRanking: List<FitLabSizeScore> = emptyList(),
)
data class FitLabReportResponse(
    val fitAnalysisResultId: String = "",
    val source: String = "fallback",
    val report: FitLabReportBody = FitLabReportBody(),
    val chartData: FitLabChartData = FitLabChartData(),
    val availableThreads: Int? = null,
)

data class FitLabCheckpoint(
    val productId: String? = null,
    val sizeIds: Map<String, String> = emptyMap(),
    val recommendationKey: String? = null,
    val reportKey: String? = null,
)

data class FitLabState(
    val screen: FitLabScreen = FitLabScreen.Sources,
    val draft: FitLabDraft = FitLabDraft(),
    val references: List<FitLabReference> = emptyList(),
    val checkpoint: FitLabCheckpoint = FitLabCheckpoint(),
    val recommendation: FitLabRecommendation? = null,
    val report: FitLabReportResponse? = null,
    val threadBalance: Int = 0,
    val step: FitLabStep = FitLabStep.Idle,
    val busy: Boolean = false,
    val error: String? = null,
    val reportError: String? = null,
    val history: List<FitLabHistorySnapshot> = emptyList(),
    val selectedHistory: FitLabHistorySnapshot? = null,
    val historySaved: Boolean = false,
)

fun measurementKeys(upper: Boolean): List<String> = if (upper) {
    listOf("shoulder_width", "chest_width", "total_length", "sleeve_length")
} else listOf("waist_width", "hip_width", "rise", "outseam")

fun measurementLabels(upper: Boolean): List<String> = if (upper) listOf("어깨", "가슴", "총장", "소매") else listOf("허리", "힙", "밑위", "총장")
