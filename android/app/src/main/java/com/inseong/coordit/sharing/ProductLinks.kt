package com.inseong.coordit.sharing

import java.net.URI

object ProductLinks {
    private val webUrl = Regex("https?://[^\\s<>\\\"]+", RegexOption.IGNORE_CASE)

    fun isProductUrl(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme?.lowercase() in setOf("http", "https") &&
            !uri.host.isNullOrBlank() && uri.rawUserInfo == null
    }.getOrDefault(false)

    fun fromText(text: String): String? = webUrl.findAll(text).map { it.value.trimEnd('.', ',', ')', ']', '}', '>', ';') }
        .firstOrNull(::isProductUrl)
}
