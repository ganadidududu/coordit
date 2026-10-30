package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.home.HomeCategory
import java.util.Locale
import kotlin.math.abs

data class ProductMeasurement(val key: String, val minimum: Double, val maximum: Double, val sizeCount: Int)

class FitLabProductReading(private val draft: FitLabDraft) {
    private val widthKey = if (draft.upper) "chest_width" else "waist_width"
    private val widthName = if (draft.upper) "가슴" else "허리"
    private val lengthKey = when {
        draft.upper -> "total_length"
        draft.category == HomeCategory.Skirt && draft.sizes.any { valid(it.measurements["total_length"]) != null } -> "total_length"
        else -> "outseam"
    }
    private val keys = if (draft.category == HomeCategory.Skirt) listOf("waist_width", "hip_width", lengthKey) else measurementKeys(draft.upper)
    val measurements = keys.mapNotNull { key ->
        val values = draft.sizes.mapNotNull { valid(it.measurements[key]) }
        if (values.isEmpty()) null else ProductMeasurement(key, values.min(), values.max(), values.size)
    }
    val hasMissingMeasurements = draft.sizes.isEmpty() || keys.any { key -> draft.sizes.any { valid(it.measurements[key]) == null } }
    private val pair = draft.sizes.zipWithNext().maxWithOrNull(
        compareBy<Pair<FitLabSizeDraft, FitLabSizeDraft>> { abs(difference(widthKey, it) ?: 0.0) }
            .thenBy { abs(difference(lengthKey, it) ?: 0.0) },
    )

    val headline: String get() {
        pair?.let { p ->
            difference(widthKey, p)?.let { width ->
                return if (abs(width) >= .05) "${p.first.label}보다 ${p.second.label}의 $widthName 단면이 ${format(abs(width))}cm ${if (width > 0) "넓어요" else "좁아요"}."
                else "두 사이즈의 $widthName 너비는 같아요."
            }
            difference(lengthKey, p)?.takeIf { abs(it) >= .05 }?.let { return "두 사이즈의 기장은 ${format(abs(it))}cm 차이가 나요." }
        }
        return if (draft.sizes.size == 1) "이 상품은 한 가지 사이즈로 나와요." else "상품에 표시된 실측을 확인해주세요."
    }

    val headlineDetail: String get() {
        val p = pair ?: return "평소 잘 맞는 옷의 너비와 길이를 기준으로 보면 고르기 쉬워요."
        val prefix = "${p.first.label}에서 ${p.second.label}로 바꿀 때의 차이예요."
        val width = difference(widthKey, p)
        val length = difference(lengthKey, p)
        if (width == null || length == null) return "$prefix 확인된 치수부터 비교했어요. 비어 있는 항목은 아래 실측표에서 확인해주세요."
        return "$prefix " + when {
            abs(width) < .05 && abs(length) >= .05 -> "기장은 달라져도 $widthName 쪽 여유는 같아요. 더 넉넉하게 입으려고 사이즈를 바꾼다면 이 부분을 먼저 보세요."
            abs(width) >= .05 && abs(length) < .05 -> "기장은 그대로이고 품만 달라져요. 길이보다 $widthName 쪽 여유를 기준으로 골라보세요."
            width * length < 0 -> "너비와 길이가 반대로 달라져요. 큰 사이즈가 모든 부위에서 더 큰 건 아니니 두 치수를 같이 봐주세요."
            abs(width) < .05 && abs(length) < .05 -> "$widthName 너비와 총장이 같아요. 다른 부위의 치수나 상품 옵션이 다른지 확인해주세요."
            else -> "품과 기장이 함께 달라져요. 원하는 여유뿐 아니라 밑단이 어디까지 내려올지도 같이 봐주세요."
        }
    }

    val overview: String get() {
        val labels = draft.sizes.joinToString(", ") { it.label }
        val sizes = if (draft.sizes.size == 1) "사이즈는 $labels 한 가지예요." else "$labels 사이즈가 있어요."
        val width = measurements.firstOrNull { it.key == widthKey }
            ?: return "$sizes $widthName 치수는 빠져 있어서, 이 부분은 상품 페이지에서 한 번 더 확인해주세요."
        val range = if (width.minimum == width.maximum) format(width.minimum) else "${format(width.minimum)}~${format(width.maximum)}"
        return "$sizes $widthName 단면은 ${range}cm로 나와 있어요. 평소 입는 사이즈와 이름이 같아도 실제 크기는 다를 수 있어요."
    }

    val sizeDifferenceTitle get() = pair?.let { "${it.first.label} → ${it.second.label} 차이" } ?: "사이즈 고를 때"
    val sizeDifference: String get() {
        val p = pair ?: return "다른 사이즈가 없어 크기 차이를 비교하긴 어려워요. 평소 잘 맞는 옷을 펼쳐 놓고 너비와 길이를 재보면 고르기 한결 수월해요."
        val sentences = mutableListOf<String>()
        difference(widthKey, p)?.let { change ->
            sentences += if (abs(change) < .05) "사이즈 이름은 다르지만 $widthName 단면은 같아요. 이 부분의 여유는 비슷하다고 보면 돼요."
            else "${p.first.label}보다 ${p.second.label}의 $widthName 단면이 ${format(abs(change))}cm 더 ${if (change > 0) "넓어요" else "좁아요"}. 둘레로는 약 ${format(abs(change) * 2)}cm 차이가 나서 $widthName 쪽${if (change > 0) " 여유가 더 있어요" else "이 더 타이트해요"}."
        }
        difference(lengthKey, p)?.takeIf { abs(it) >= .05 }?.let { change ->
            val subject = if (sentences.isEmpty()) "${p.first.label}보다 ${p.second.label}의 총장이" else "총장은"
            sentences += "$subject ${format(abs(change))}cm 더 ${if (change > 0) "길어요" else "짧아요"}."
        }
        return sentences.joinToString(" ").ifEmpty { "두 사이즈에 공통으로 적힌 치수가 부족해 크기 차이를 비교하기 어려워요. 아래 실측표에 나온 부분부터 확인해주세요." }
    }

    val wearingContext: String get() = when (draft.category) {
        HomeCategory.Tshirt -> "티셔츠는 가슴과 어깨를 같이 보세요. 어깨선이 내려오는 디자인은 수치가 커도 자연스럽게 떨어지는 편이에요. 기장이 짧고 품이 넓으면 더 박시해 보이고요."
        HomeCategory.Shirt -> "셔츠는 단추를 잠갔을 때 가슴이 당기지 않는지가 중요해요. 티셔츠 위에 걸쳐 입을 거라면 그만큼 여유를 남겨주세요. 품이 넓어도 어깨와 소매가 맞으면 덜 커 보여요."
        HomeCategory.Sweatshirt -> "밑단에 시보리가 있는 맨투맨은 옷자락이 모이면서 볼륨이 생겨요. 그래서 품이 넓어도 마냥 큰 옷처럼 보이진 않아요. 가슴 너비와 총장을 같이 봐주세요."
        HomeCategory.Hoodie -> "후드는 안에 입을 옷까지 생각해서 골라주세요. 기모나 안감이 두꺼우면 같은 치수라도 안쪽은 더 꽉 차요. 후드와 내려오는 어깨선 때문에 상체가 더 커 보이기도 해요."
        HomeCategory.Knit -> "니트는 짜임과 신축성에 따라 몸에 붙기도, 느슨하게 떨어지기도 해요. 같은 치수라도 느낌이 꽤 달라서 소재 설명을 같이 보는 게 좋아요. 어깨가 부드럽게 내려오면 수치보다 덜 커 보이고요."
        HomeCategory.Jacket -> "재킷은 품보다 어깨선이 먼저 눈에 들어와요. 어깨 패드가 있으면 실측이 비슷해도 더 각지고 커 보이는 편이에요. 안에 두꺼운 옷을 입을 거라면 가슴과 소매 여유도 챙겨주세요."
        HomeCategory.Coat -> "코트는 안에 뭘 입을지부터 생각해보세요. 니트나 재킷 위에 입으면 그만큼 안쪽 여유가 줄어요. 품이 비슷해도 기장이 길면 전체적으로 더 커 보일 수 있어요."
        HomeCategory.Pants -> "팬츠는 허리가 맞아도 앉았을 때 엉덩이나 밑위가 불편할 수 있어요. 세 치수를 함께 봐주세요. 밴딩 허리라면 표에 적힌 수치가 늘리기 전인지도 확인하는 게 좋아요."
        HomeCategory.Jeans -> "데님은 신축성부터 확인해주세요. 잘 늘어나지 않는 원단이면 같은 허리·엉덩이 치수도 더 타이트하게 느껴져요. 입다 보면 늘어나겠지 하고 작은 사이즈를 고르는 건 피하는 게 좋아요."
        HomeCategory.Shorts -> "반바지는 허리를 어디까지 올려 입느냐에 따라 보이는 기장이 달라져요. 밑위와 총장을 같이 보세요. 기장이 짧고 통이 넓으면 실제 너비보다 더 여유로워 보이는 편이에요."
        HomeCategory.Skirt -> "스커트는 허리 위치와 엉덩이 여유를 같이 봐주세요. 일자 디자인은 엉덩이 쪽이 붙기 쉽고, 퍼지는 디자인은 같은 허리 치수라도 더 넉넉해 보여요."
    }

    private fun difference(key: String, p: Pair<FitLabSizeDraft, FitLabSizeDraft>): Double? {
        val first = valid(p.first.measurements[key]) ?: return null
        return valid(p.second.measurements[key])?.minus(first)
    }
    companion object {
        private fun valid(value: Double?) = value?.takeIf { it.isFinite() && it > 0 }
        fun format(value: Double) = String.format(Locale.US, "%.1f", value).removeSuffix(".0")
    }
}
