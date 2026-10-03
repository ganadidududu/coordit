package com.inseong.coordit.data.closet

import kotlin.math.abs

/** Coordinates use image pixels, with the origin at the upper left. */
data class OcrCell(val text: String, val x: Float, val y: Float, val width: Float, val height: Float) {
    val centerX get() = x + width / 2
    val centerY get() = y + height / 2
}
data class OcrRow(val label: String, val measurements: Map<String, Double>)

object ClosetOcr {
    private val aliases = mapOf(
        "shoulder_width" to setOf("어깨", "어깨너비", "어깨단면", "shoulder", "shoulderwidth"),
        "chest_width" to setOf("가슴", "가슴너비", "가슴단면", "chest", "chestwidth", "bust"),
        "total_length" to setOf("총장", "기장", "length", "totallength", "bodylength"),
        "sleeve_length" to setOf("소매", "소매길이", "팔길이", "sleeve", "sleevelength"),
        "waist_width" to setOf("허리", "허리너비", "허리단면", "waist", "waistwidth"),
        "hip_width" to setOf("엉덩이", "엉덩이너비", "엉덩이단면", "hip", "hipwidth"),
        "rise" to setOf("밑위", "rise", "frontrise"),
        "outseam" to setOf("바지길이", "아웃심", "outseam", "pantslength"),
    )
    private fun normalize(text: String) = text.lowercase().replace(Regex("\\(.*?\\)|\\[.*?\\]"), "").filter(Char::isLetter)
    private fun key(text: String, upper: Boolean): String? {
        val normalized = normalize(text)
        val found = aliases.entries.firstOrNull { normalized in it.value }?.key ?: return null
        if (!upper && found == "total_length") return "outseam"
        return found.takeIf { if (upper) it in setOf("shoulder_width", "chest_width", "total_length", "sleeve_length") else it in setOf("waist_width", "hip_width", "rise", "outseam") }
    }
    private fun isSize(text: String) = normalize(text) in setOf("size", "사이즈", "호수", "치수")
    private fun number(text: String): Double? = text.trim().lowercase().removeSuffix("cm").trim()
        .replace(',', '.').takeIf { it.matches(Regex("\\d{1,3}(\\.\\d{1,2})?")) }
        ?.toDoubleOrNull()?.takeIf { it > 0 && it <= 300 }
    private fun label(text: String): String? = text.trim().takeIf {
        it.matches(Regex("(?i)([2-6]?X{0,3}[SML]|FREE|ONE\\s?SIZE|OS|F|\\d{2,3})"))
    }

    fun parse(cells: List<OcrCell>, upper: Boolean): List<OcrRow> {
        val rows = mutableListOf<MutableList<OcrCell>>()
        cells.filter { it.width > 0 && it.height > 0 }.sortedBy { it.centerY }.forEach { cell ->
            val row = rows.firstOrNull { abs(it.map(OcrCell::centerY).average() - cell.centerY) <= minOf(it.map(OcrCell::height).average(), cell.height.toDouble()) * .55 }
            if (row == null) rows.add(mutableListOf(cell)) else row.add(cell)
        }
        rows.forEach { it.sortBy(OcrCell::centerX) }
        val horizontal = rows.indexOfFirst { row -> row.any { isSize(it.text) } && row.count { key(it.text, upper) != null } >= 2 }
        if (horizontal >= 0) {
            val header = rows[horizontal]
            val columns = header.mapNotNull { cell -> key(cell.text, upper)?.let { it to cell.centerX } }
            if (columns.map { it.first }.distinct().size != columns.size) return emptyList()
            val sizeX = header.first { isSize(it.text) }.centerX
            val allX = columns.map { it.second } + sizeX
            val parsed = rows.drop(horizontal + 1).mapNotNull { row ->
                val sizeCell = aligned(row, sizeX, allX) ?: return@mapNotNull null
                val sizeLabel = label(sizeCell.text) ?: return@mapNotNull null
                val values = columns.mapNotNull { (key, x) -> aligned(row, x, allX)?.let { number(it.text) }?.let { key to it } }.toMap()
                if (values.size < 2) null else OcrRow(sizeLabel, values)
            }
            return parsed.takeIf { it.map(OcrRow::label).distinct().size == it.size } ?: emptyList()
        }
        val vertical = rows.indexOfFirst { row -> row.any { isSize(it.text) } && row.count { label(it.text) != null } >= 1 }
        if (vertical < 0) return emptyList()
        val header = rows[vertical]
        val sizeColumns = header.mapNotNull { cell -> label(cell.text)?.let { it to cell.centerX } }
        if (sizeColumns.map { it.first }.distinct().size != sizeColumns.size) return emptyList()
        val keyX = header.first { isSize(it.text) }.centerX
        val allX = sizeColumns.map { it.second } + keyX
        val values = sizeColumns.associate { it.first to mutableMapOf<String, Double>() }
        for (row in rows.drop(vertical + 1)) {
            val measurement = aligned(row, keyX, allX)?.let { key(it.text, upper) } ?: continue
            for ((size, x) in sizeColumns) {
                val value = aligned(row, x, allX)?.let { number(it.text) } ?: continue
                if (values.getValue(size).put(measurement, value) != null) return emptyList()
            }
        }
        return sizeColumns.mapNotNull { (size, _) -> values.getValue(size).takeIf { it.size >= 2 }?.let { OcrRow(size, it.toMap()) } }
    }

    private fun aligned(row: List<OcrCell>, x: Float, columns: List<Float>): OcrCell? {
        val spacing = columns.filter { it != x }.minOfOrNull { abs(it - x) } ?: return null
        val candidates = row.filter { abs(it.centerX - x) < spacing * .45f }
        return candidates.singleOrNull()
    }
}
