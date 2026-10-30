package com.inseong.coordit.data.fitlab

import java.time.Instant

data class ProductFact(val kind: String, val value: String)
data class ProductFacts(val productName: String, val sourceUrl: String, val capturedAt: String, val items: List<ProductFact>) {
    val checkedDate: Instant? get() = runCatching { Instant.parse(capturedAt) }.getOrNull()
    fun appliesTo(draft: FitLabDraft): Boolean = draft.source == FitLabSource.Url &&
        sourceUrl == draft.productUrl && productName.trim() == draft.productName.trim() && checkedDate != null &&
        (sourceUrl.startsWith("https://") || sourceUrl.startsWith("http://"))

    fun summary(kinds: List<String>): String? {
        val labels = mapOf("material" to "소재", "lining" to "안감", "stretch" to "신축성", "thickness" to "두께", "sheerness" to "비침", "fit" to "핏", "model" to "모델", "care" to "관리")
        return kinds.mapNotNull { kind ->
            val item = items.filter { it.kind == kind }.singleOrNull() ?: return@mapNotNull null
            val label = labels[kind] ?: return@mapNotNull null
            item.value.takeIf { it.isNotBlank() && it.length <= 80 }?.let { "$label · $it" }
        }.joinToString("\n").ifEmpty { null }
    }
}
