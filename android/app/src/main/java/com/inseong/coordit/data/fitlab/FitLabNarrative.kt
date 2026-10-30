package com.inseong.coordit.data.fitlab

import java.text.Normalizer
import kotlin.math.floor

internal data class NarrativeFiber(val id: String, val name: String, val aliases: List<String>, val trait: String, val caution: String)
data class NarrativeComponent(val fiberID: String, val name: String, val percent: Double)
enum class NarrativeShape { Unknown, Boxy, Mixed }

class FitLabNarrative(private val draft: FitLabDraft) {
    private val facts = draft.productFacts?.takeIf { it.appliesTo(draft) }
    private fun fact(kind: String) = facts?.items?.filter { it.kind == kind }?.singleOrNull()?.value
    private fun normalized(text: String) = Normalizer.normalize(text, Normalizer.Form.NFKC).lowercase(java.util.Locale.ROOT).replace(" ", "")
    val components: List<NarrativeComponent> get() {
        val material = fact("material") ?: return emptyList()
        val text = Normalizer.normalize(material, Normalizer.Form.NFKC).lowercase(java.util.Locale.ROOT).replace(',', '.')
        if (Regex("안감|충전|배색|lining|filling|[-~]\\s*[0-9]|이상|이하|약|approx|less|more").containsMatchIn(text)) return emptyList()
        val patterns = listOf("([a-z가-힣][a-z가-힣 \\-]*?)\\s*[:：]?\\s*\\(?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*%", "([0-9]+(?:\\.[0-9]+)?)\\s*%\\s*([a-z가-힣][a-z가-힣 \\-]*)")
        val count = text.count { it == '%' }
        if (count == 0) return emptyList()
        patterns.forEachIndexed { direction, pattern ->
            val matches = Regex(pattern).findAll(text).toList()
            if (matches.size != count) return@forEachIndexed
            val parsed = mutableListOf<NarrativeComponent>()
            matches.forEach { match ->
                val nameIndex = if (direction == 0) 1 else 2
                val percentIndex = if (direction == 0) 2 else 1
                val percent = match.groupValues[percentIndex].toDoubleOrNull() ?: return emptyList()
                if (percent !in 0.0..100.0) return emptyList()
                val rawName = match.groupValues[nameIndex].trim().replace(Regex("^(겉감|소재|혼용률|material|composition|recycled|organic|오가닉|유기농|리사이클드|리사이클)\\s*[:：]?\\s*"), "")
                val fiber = NarrativeRules.fibers.firstOrNull { f -> f.aliases.any { normalized(it) == normalized(rawName) } } ?: return emptyList()
                if (parsed.any { it.fiberID == fiber.id } || (fiber.id == "elastane" && percent > NarrativeRules.maximumElastanePercent)) return emptyList()
                parsed += NarrativeComponent(fiber.id, fiber.name, percent)
            }
            if (parsed.sumOf { it.percent } !in NarrativeRules.minimumCompositionTotal..NarrativeRules.maximumCompositionTotal) return emptyList()
            return parsed.filter { it.percent > 0 }.sortedWith(compareByDescending<NarrativeComponent> { it.percent }.thenBy { it.fiberID })
        }
        return emptyList()
    }
    private val ratios: List<Double> get() {
        if (draft.category.wireName !in NarrativeRules.boxyMinimums || draft.sizes.size < 2) return emptyList()
        val values = draft.sizes.mapNotNull { row ->
            val width = row.measurements["chest_width"] ?: return@mapNotNull null
            val length = row.measurements["total_length"] ?: return@mapNotNull null
            if (!width.isFinite() || !length.isFinite() || width !in NarrativeRules.widthBounds || length !in NarrativeRules.lengthBounds) null else width / length
        }
        return values.takeIf { it.size == draft.sizes.size }.orEmpty()
    }
    val shape: NarrativeShape get() {
        val threshold = NarrativeRules.boxyMinimums[draft.category.wireName] ?: return NarrativeShape.Unknown
        val values = ratios
        return when {
            values.isEmpty() -> NarrativeShape.Unknown
            values.all { it >= threshold } -> NarrativeShape.Boxy
            values.any { it >= threshold } -> NarrativeShape.Mixed
            else -> NarrativeShape.Unknown
        }
    }
    val stretchConflict get() = components.any { it.fiberID == "elastane" } && fact("stretch")?.let { Regex("없|무신축|non.?stretch|^(no|none)$").containsMatchIn(it.lowercase(java.util.Locale.ROOT)) } == true
    val fitConflict get() = shape == NarrativeShape.Boxy && fact("fit")?.let { !Regex("아니|아님|않|not|non").containsMatchIn(it.lowercase(java.util.Locale.ROOT)) && Regex("슬림|타이트|slim|tight").containsMatchIn(it.lowercase(java.util.Locale.ROOT)) } == true
    val traitIDs get() = components.filter { component -> component.fiberID != "elastane" && component.percent >= NarrativeRules.minimumTraitPercent && NarrativeRules.fibers.any { it.id == component.fiberID && it.trait.isNotEmpty() } }.take(2).map { it.fiberID }
    private fun render(key: String, values: Map<String, String> = emptyMap()) = values.entries.fold(NarrativeRules.text[key].orEmpty()) { text, (key, value) -> text.replace("{$key}", value) }
    private fun number(value: Double) = FitLabProductReading.format(value)
    val paragraph: String get() {
        val sentences = mutableListOf<String>()
        if (traitIDs.isNotEmpty()) {
            val blend = components.joinToString("·") { "${it.name} ${number(it.percent)}%" }
            val selected = traitIDs.mapNotNull { id -> NarrativeRules.fibers.firstOrNull { it.id == id } }
            val traits = selected.map { it.trait }.distinct().joinToString("과 ") { trait ->
                selected.filter { it.trait == trait }.joinToString("·") { it.name } + "의 " + trait
            }
            sentences += render("material", mapOf("blend" to blend, "traits" to traits))
            components.firstOrNull()?.let { dominant ->
                NarrativeRules.fibers.firstOrNull { it.id == dominant.fiberID }?.caution?.takeIf { dominant.percent >= 50 && it.isNotEmpty() }?.let { sentences += it }
            }
        }
        val stretch = fact("stretch")
        if (stretch != null && stretch.length <= 24) sentences += "신축성은 ‘$stretch’으로 표시돼 있어요."
        else if (!stretchConflict) components.firstOrNull { it.fiberID == "elastane" && it.percent >= 1 }?.let { sentences += render("stretch", mapOf("percent" to number(it.percent))) }
        if (fitConflict) sentences += render("conflict")
        else {
            fact("fit")?.takeIf { it.length <= 24 }?.let { sentences += render("sellerFit", mapOf("value" to it)) }
            when (shape) {
                NarrativeShape.Boxy -> ratios.takeIf { it.isNotEmpty() }?.let { values -> sentences += render("boxy", mapOf("count" to values.size.toString(), "minimum" to number(floor(values.min() * 100 + .5)), "maximum" to number(floor(values.max() * 100 + .5)))) }
                NarrativeShape.Mixed -> sentences += render("mixed")
                NarrativeShape.Unknown -> Unit
            }
        }
        return sentences.joinToString(" ")
    }
}
