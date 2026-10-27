package com.inseong.coordit.data.fitlab.camera

import kotlin.math.sqrt

/** Camera inputs never change the existing FitLab/OCR persistence contract. */
object GarmentMeasurementPolicy {
    val categories = setOf("tshirt", "shirt", "sweatshirt", "hoodie", "knit", "jacket", "coat", "pants", "jeans", "shorts", "skirt")
    fun dimensions(category: String): List<String> {
        require(category in categories)
        return when (category) {
            "skirt" -> listOf("waist_width", "hip_width", "total_length")
            "pants", "jeans", "shorts" -> listOf("waist_width", "hip_width", "rise", "outseam")
            else -> listOf("shoulder_width", "chest_width", "total_length", "sleeve_length")
        }
    }
    fun centimeters(start: List<Float>, end: List<Float>): Double {
        require(start.size == 3 && end.size == 3 && (start + end).all { it.isFinite() })
        return sqrt(start.zip(end).sumOf { (a, b) -> (a - b).toDouble().let { it * it } }) * 100
    }
    fun plausible(key: String, centimeters: Double): Boolean = centimeters.isFinite() && when (key) {
        "shoulder_width" -> centimeters in 15.0..100.0
        "chest_width" -> centimeters in 20.0..120.0
        "total_length" -> centimeters in 25.0..150.0
        "sleeve_length" -> centimeters in 3.0..90.0
        "waist_width" -> centimeters in 20.0..90.0
        "hip_width" -> centimeters in 25.0..100.0
        "rise" -> centimeters in 10.0..60.0
        "outseam" -> centimeters in 20.0..150.0
        else -> false
    }
}
