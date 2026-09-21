package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.closet.ClosetPrefillRequest
import com.inseong.coordit.data.closet.ClosetPrefillResponse
import com.inseong.coordit.data.model.ThreadBalanceResponse
import retrofit2.http.*

interface FitLabApi {
    @GET("thread-wallet/balance") suspend fun balance(@Header("Authorization") auth: String): ThreadBalanceResponse
    @GET("reference-clothing/by-category/{category}") suspend fun references(@Header("Authorization") auth: String, @Path("category") category: String): List<FitLabReference>
    @POST("external-products/from-url") suspend fun prefill(@Header("Authorization") auth: String, @Body request: ClosetPrefillRequest): ClosetPrefillResponse
    @POST("external-products") suspend fun product(@Header("Authorization") auth: String, @Body request: FitLabProductRequest): FitLabProductResponse
    @POST("external-products/{id}/sizes") suspend fun size(@Header("Authorization") auth: String, @Path("id") id: String, @Body request: FitLabSizeRequest): FitLabSizeResponse
    @POST("fit/recommend") suspend fun recommend(@Header("Authorization") auth: String, @Body request: FitLabRecommendRequest): FitLabRecommendation
    @POST("fit-analysis-results/{id}/report") suspend fun report(@Header("Authorization") auth: String, @Path("id") id: String, @Body request: FitLabReportRequest): FitLabReportResponse
}

class FitLabRepository(private val api: FitLabApi) {
    private fun auth(token: String) = "Bearer ${token.also { require(it.isNotBlank()) { "로그인이 필요해요." } }}"
    suspend fun balance(token: String) = api.balance(auth(token)).availableThreads
    suspend fun references(token: String, category: String) = api.references(auth(token), category).filter { it.isActive }
    suspend fun prefill(token: String, url: String, category: String) = api.prefill(auth(token), ClosetPrefillRequest(url, category))
    suspend fun product(token: String, draft: FitLabDraft) = api.product(auth(token), FitLabProductRequest(draft.productName.trim(), draft.brand.trim().ifBlank { null }, productUrl = draft.productUrl.ifBlank { null }, category = draft.category.wireName))
    suspend fun size(token: String, productId: String, row: FitLabSizeDraft, source: FitLabSource): FitLabSizeResponse {
        val m = row.measurements
        val parsingStatus = when (source) { FitLabSource.Manual -> null; FitLabSource.Ocr -> "parsed"; FitLabSource.Url -> "confirmed" }
        val extractionConfidence = if (source == FitLabSource.Ocr) 0.72 else null
        return api.size(auth(token), productId, FitLabSizeRequest(row.label.trim(), parsingStatus, source.name.lowercase(), extractionConfidence,
            m["shoulder_width"], m["chest_width"], m["total_length"], m["sleeve_length"], m["waist_width"], m["hip_width"], m["rise"], m["outseam"]))
    }
    suspend fun recommend(token: String, refs: Set<String>, productId: String, key: String) = api.recommend(auth(token), FitLabRecommendRequest(refs.sorted(), productId, key))
    suspend fun report(token: String, result: FitLabRecommendation, key: String) = api.report(auth(token), result.fitAnalysisResultId, FitLabReportRequest(key, result.recommendedSize))
}
