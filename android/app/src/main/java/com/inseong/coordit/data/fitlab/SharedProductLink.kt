package com.inseong.coordit.data.fitlab

import java.net.URI

fun sharedProductLink(text: String?): String? = text?.let { value ->
    Regex("https?://[^\\s<>]+", RegexOption.IGNORE_CASE).findAll(value).map { it.value.trimEnd('.', ',', ')', ']', '"', '\'') }
        .firstOrNull { candidate -> runCatching { URI(candidate) }.getOrNull()?.let { !it.host.isNullOrBlank() } == true }
}
