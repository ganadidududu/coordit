package com.inseong.coordit.data.fitlab.camera

import android.graphics.Bitmap
import android.util.Base64
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.inseong.coordit.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/** Authenticated, explicitly consented proposal adapter, disabled by default.
 * It never writes photos, EXIF, measurements, wallet balances or model-training records.
 */
class GarmentLandmarkClient {
    data class Input(val bitmap: Bitmap, val category: String, val endpoint: String,
                     val bearerToken: String, val processingConsent: Boolean)
    data class NormalizedPoint(val x: Float, val y: Float)
    data class Landmark(val x: Double?, val y: Double?, @SerializedName("landmark_type") val type: String?,
                        val visibility: Int?, val confidence: Double?, val source: String?,
                        @SerializedName("correction_status") val correctionStatus: String?)
    data class Response(@SerializedName("schema_version") val schemaVersion: Int?, val status: String?,
                        @SerializedName("model_version") val modelVersion: String?, val category: String?,
                        @SerializedName("coordinate_system") val coordinateSystem: String?,
                        @SerializedName("deployment_approved") val deploymentApproved: Boolean?,
                        val landmarks: List<Landmark?>?) {
        fun validatedEndpoints(expectedCategory: String, allowDevelopment: Boolean = false): List<NormalizedPoint>? {
            if (schemaVersion != 1 || modelVersion.isNullOrBlank() || (deploymentApproved != true && !allowDevelopment) || category != expectedCategory ||
                coordinateSystem != "upright_rgb_normalized_top_left" || status != "needs_calibration") return null
            val decoded = landmarks ?: return null
            if (decoded.any { it == null }) return null
            val points = decoded.filterNotNull()
            if (points.map { it.type }.toSet().size != points.size) return null
            val names = when (category) {
                "skirt" -> listOf("waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "skirt_hem")
                "pants", "jeans", "shorts" -> listOf("waist_left", "waist_right", "hip_left", "hip_right", "waist_center", "crotch", "side_waist", "side_hem")
                in GarmentMeasurementPolicy.categories -> listOf("shoulder_left", "shoulder_right", "armpit_left", "armpit_right", "length_start", "hem_center", "sleeve_start", "sleeve_end")
                else -> return null
            }
            return names.map { name ->
                val point = points.singleOrNull { it.type == name } ?: return null
                val x = point.x ?: return null
                val y = point.y ?: return null
                val confidence = point.confidence ?: return null
                if (!x.isFinite() || !y.isFinite() || !confidence.isFinite() || x !in 0.0..1.0 || y !in 0.0..1.0 ||
                    point.visibility != 2 || confidence !in .7..1.0) return null
                NormalizedPoint(x.toFloat(), y.toFloat())
            }
        }
    }
    sealed interface Outcome {
        data class Proposal(val response: Response) : Outcome
        data class Fallback(val reason: String) : Outcome
    }
    private val http = OkHttpClient.Builder().connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS).callTimeout(10, TimeUnit.SECONDS).followRedirects(false).followSslRedirects(false).build()

    suspend fun infer(input: Input): Outcome = withContext(Dispatchers.IO) {
        if (!BuildConfig.AI_LANDMARKS_ENABLED) return@withContext Outcome.Fallback("feature_disabled")
        if (!input.processingConsent || !input.endpoint.startsWith("https://")) return@withContext Outcome.Fallback("consent_or_transport_required")
        val scale = minOf(1.0, 1600.0 / maxOf(input.bitmap.width, input.bitmap.height))
        val pixels = if (scale < 1) Bitmap.createScaledBitmap(input.bitmap,
            (input.bitmap.width * scale).toInt(), (input.bitmap.height * scale).toInt(), true) else input.bitmap
        val bytes = ByteArrayOutputStream().use { stream -> pixels.compress(Bitmap.CompressFormat.JPEG, 85, stream); stream.toByteArray() }
        if (pixels !== input.bitmap) pixels.recycle()
        if (bytes.size > 3_000_000) return@withContext Outcome.Fallback("image_too_large")
        val payload = Gson().toJson(mapOf("image_base64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
            "processing_consent" to true, "training_consent" to false))
        val request = Request.Builder().url(input.endpoint).header("Authorization", "Bearer ${input.bearerToken}")
            .post(payload.toRequestBody("application/json".toMediaType())).build()
        try {
            http.newCall(request).execute().use { result ->
                val body = result.body
                if (!result.isSuccessful || body == null || body.contentLength() > 1_000_000L) {
                    return@withContext Outcome.Fallback("server_unavailable")
                }
                val raw = body.source().use { source ->
                    source.request(1_000_001L)
                    source.buffer.readByteArray(minOf(source.buffer.size, 1_000_001L))
                }
                if (raw.size > 1_000_000) return@withContext Outcome.Fallback("response_too_large")
                val parsed: Response? = Gson().fromJson(raw.toString(Charsets.UTF_8), Response::class.java)
                if (parsed?.validatedEndpoints(input.category, BuildConfig.DEBUG && BuildConfig.AI_LANDMARKS_DEVELOPMENT_ENABLED) == null) Outcome.Fallback("model_or_landmarks_unapproved")
                else Outcome.Proposal(parsed)
            }
        } catch (error: IOException) {
            Outcome.Fallback("network_unavailable")
        } catch (error: com.google.gson.JsonParseException) {
            Outcome.Fallback("invalid_server_contract")
        }
    }
}
