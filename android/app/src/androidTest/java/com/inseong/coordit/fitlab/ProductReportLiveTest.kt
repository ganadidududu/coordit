package com.inseong.coordit.fitlab

import androidx.test.platform.app.InstrumentationRegistry
import com.google.gson.JsonParser
import kotlinx.coroutines.runBlocking
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.util.concurrent.TimeUnit

/** Explicitly opted-in, read-only smoke against an already signed-in development app. */
class ProductReportLiveTest {
    @Test fun authenticatedPreviewDoesNotSpendThreads() = runBlocking {
        val arguments = InstrumentationRegistry.getArguments()
        val base = arguments.getString("reportBaseUrl")
        val product = arguments.getString("reportProductUrl")
        assumeTrue(base?.startsWith("https://") == true && product?.startsWith("https://") == true)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val session = checkNotNull(com.inseong.coordit.AppContainer(context).repository.restore()) { "Sign in before this opt-in smoke" }
        val client = OkHttpClient.Builder().callTimeout(70, TimeUnit.SECONDS).build()
        val root = checkNotNull(base).trimEnd('/')
        fun request(path: String, body: String? = null): Pair<Int, String> {
            val builder = Request.Builder().url("$root/$path").header("Authorization", "Bearer ${session.accessToken}")
            if (body != null) builder.post(body.toRequestBody("application/json".toMediaType()))
            return client.newCall(builder.build()).execute().use { it.code to it.body.orEmpty() }
        }
        val before = request("thread-wallet/balance")
        assertEquals("Authenticated wallet read failed", 200, before.first)
        val invalid = request("external-products/from-url", """{"url":"invalid"}""")
        assertEquals(400, invalid.first)
        val body = com.google.gson.Gson().toJson(mapOf("url" to product))
        val preview = request("external-products/from-url", body)
        val after = request("thread-wallet/balance")
        assertEquals(200, after.first)
        assertEquals(JsonParser.parseString(before.second), JsonParser.parseString(after.second))
        assertTrue("Unexpected preview response ${preview.first}", preview.first in listOf(200, 422, 429, 502, 504))
        val report = JsonParser.parseString(preview.second).asJsonObject
        val output = com.google.gson.JsonObject().apply {
            addProperty("previewStatus", preview.first)
            addProperty("walletUnchanged", true)
            if (preview.first == 200) {
                add("productName", report.get("productName"))
                addProperty("sizeCount", report.getAsJsonArray("sizes").size())
                add("productFacts", report.get("productFacts"))
            } else add("message", report.get("message"))
        }
        val directory = File(context.getExternalFilesDir(null), "product-first-report").apply { mkdirs() }
        File(directory, "live-api-smoke.json").writeText(output.toString())
    }
}

private fun okhttp3.ResponseBody?.orEmpty(): String = this?.string().orEmpty()
