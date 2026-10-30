package com.inseong.coordit.data.fitlab

import com.inseong.coordit.data.closet.ClosetPrefillResponse
import com.inseong.coordit.data.closet.ClosetSizeResponse
import com.inseong.coordit.data.home.HomeCategory

object FitLabExample {
    const val link = "https://example.coordit.invalid/products/basic"
    fun product(category: HomeCategory): ClosetPrefillResponse = ClosetPrefillResponse(
        "[예시] 베이직 ${category.title}",
        listOf("S", "M", "L").mapIndexed { index, label ->
            val offset = index * 2.0
            if (category.upper) ClosetSizeResponse("example-$label", label, 66 + offset, 44 + offset, 50 + offset, 20 + offset, null, null, null, null)
            else ClosetSizeResponse("example-$label", label, if (category == HomeCategory.Skirt) 96 + offset else null, null, null, null, 36 + offset, 48 + offset, if (category == HomeCategory.Skirt) null else 27 + offset, if (category == HomeCategory.Skirt) null else 96 + offset)
        }, category.wireName, mallName = "예시 체험",
    )
    fun references(category: HomeCategory) = listOf(FitLabReference("tutorial-reference", "tutorial-clothing", "[예시] 나에게 잘 맞는 ${category.title}", category.wireName, true))
    fun recommendation(draft: FitLabDraft): FitLabRecommendation {
        val selected = draft.sizes.firstOrNull { it.label == "M" } ?: draft.sizes.first()
        return FitLabRecommendation("tutorial-example", selected.label, 95.0, "예시 점수", "흐름을 설명하기 위한 예시 결과예요.", "example", selected.measurements.mapValues { 1.0 }, draft.sizes.map { FitLabSizeScore(it.label, if (it.id == selected.id) 95.0 else 82.0) })
    }
    fun report(result: FitLabRecommendation) = FitLabReportResponse(result.fitAnalysisResultId, "example", FitLabReportBody(
        "예시 핏 리포트", "사이즈별 점수와 기준 옷과의 차이를 이렇게 확인할 수 있어요.",
        cautions = listOf("체험용으로 준비한 점수이며 실제 체형이나 입력값을 분석한 결과가 아니에요."),
        nextActions = listOf("체험을 마치고 내 상품과 기준 옷으로 분석해 보세요."),
    ), FitLabChartData(sizeScoreRanking = result.allSizeScores))
}
