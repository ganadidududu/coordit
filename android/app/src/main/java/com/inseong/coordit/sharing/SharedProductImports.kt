package com.inseong.coordit.sharing

import android.content.Context
import android.content.Intent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray

class SharedProductImports(context: Context) {
    private val preferences = context.getSharedPreferences("shared-product-imports", Context.MODE_PRIVATE)
    private val queue = MutableStateFlow(read())
    val pending = queue.asStateFlow()

    fun accept(intent: Intent?) {
        val url = when (intent?.action) {
            Intent.ACTION_SEND -> if (intent.type == "text/plain") {
                ProductLinks.fromText(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty())
            } else null
            Intent.ACTION_VIEW -> intent.data?.let { data ->
                if (data.scheme == "coordit" && data.host == "fitlab" && data.path == "/shared") {
                    data.getQueryParameter("url")?.takeIf(ProductLinks::isProductUrl)
                } else null
            }
            else -> null
        } ?: return
        if (url !in queue.value) write((queue.value + url).takeLast(20))
    }

    fun consume(url: String) { write(queue.value.filterNot { it == url }) }

    private fun read(): List<String> = runCatching {
        val values = JSONArray(preferences.getString("queue", "[]"))
        (0 until values.length()).map { values.getString(it) }.filter(ProductLinks::isProductUrl).distinct()
    }.getOrDefault(emptyList())

    private fun write(values: List<String>) {
        if (preferences.edit().putString("queue", JSONArray(values).toString()).commit()) queue.value = values
    }
}
