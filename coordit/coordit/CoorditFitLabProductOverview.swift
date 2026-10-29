import SwiftUI

#if os(iOS)
struct CoorditFitLabProductOverview: View {
    let draft: CoorditFitLabDraft
    let metrics: CoorditResponsiveMetrics
    @State private var selectedSizeID: UUID?
    @State private var showsMeasurements = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selected: CoorditFitLabSizeDraft? { draft.sizes.first { $0.id == selectedSizeID } ?? draft.sizes.first }
    private var summary: CoorditFitLabProductSummary { .init(draft: draft) }
    private var reading: CoorditFitLabProductReading { .init(draft: draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(14)) {
            Label("1차 분석 · 무료", systemImage: "checkmark.circle")
                .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .caption))
                .accessibilityIdentifier("fitlab-free-summary")
            Text(draft.productName)
                .font(CoorditTypography.gmarketBold(size: metrics.value(19), relativeTo: .title3))
            Text([draft.brand, draft.category.koreanTitle, draft.mallName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(CoorditFitLabPalette.muted)
            Text(draft.source == .url ? "상품 링크의 정보만으로 정리했어요. 실타래는 사용하지 않아요." : "입력한 상품과 치수로 정리했어요. 실타래는 사용하지 않아요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            VStack(alignment: .leading, spacing: metrics.value(12)) {
                Label("이 옷, 여기부터 보세요", systemImage: "viewfinder")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                Text(reading.headline)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(23), relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                Text(reading.headlineDetail)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    .lineSpacing(metrics.value(5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(metrics.value(18))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CoorditFitLabPalette.ink.gradient, in: RoundedRectangle(cornerRadius: metrics.value(12)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("fitlab-summary-highlight")
            readingParagraph(title: "사이즈 요약", body: reading.overview, symbol: "ruler")
            readingParagraph(title: reading.sizeDifferenceTitle, body: reading.sizeDifference, symbol: "arrow.left.arrow.right")
                .accessibilityIdentifier("fitlab-summary-size-reading")
            readingParagraph(title: "입을 때 볼 점", body: reading.wearingContext, symbol: "tshirt")
                .accessibilityIdentifier("fitlab-summary-wearing-context")
            Text("실측표와 옷 종류를 바탕으로 정리했어요. 실제 착용감은 원단과 디자인에 따라 달라져요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(CoorditMotion.navigation(reduceMotion: reduceMotion)) {
                    showsMeasurements.toggle()
                }
            } label: {
                HStack {
                    Text(showsMeasurements ? "상세 실측표 접기" : "상세 실측표 펼치기")
                    Spacer()
                    Image(systemName: showsMeasurements ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
            .accessibilityIdentifier("fitlab-toggle-measurements")
            .accessibilityValue(showsMeasurements ? "펼쳐짐" : "접힘")
            if showsMeasurements {
            Text("사이즈 \(draft.sizes.count)개 · 실측 범위")
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
            ForEach(summary.measurements) { measurement in
                HStack(alignment: .firstTextBaseline) {
                    Text(label(measurement.key))
                    Spacer()
                    Text(measurement.minimum == measurement.maximum
                         ? "\(number(measurement.minimum)) cm"
                         : "\(number(measurement.minimum))–\(number(measurement.maximum)) cm")
                }
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
            }
            if summary.hasMissingMeasurements {
                Text("일부 치수는 제공되지 않았어요. 확인된 수치만 표시했어요.")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                    .foregroundStyle(CoorditFitLabPalette.muted)
                    .accessibilityIdentifier("fitlab-summary-missing-measurements")
            }
            Text("사이즈별로 살펴보기")
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
            ScrollView(.horizontal) {
                HStack(spacing: metrics.value(8)) {
                    ForEach(draft.sizes) { size in
                        Button(size.label) { selectedSizeID = size.id }
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: size.id == selected?.id ? .primary : .secondary))
                            .frame(minWidth: metrics.value(60))
                            .accessibilityIdentifier("fitlab-product-size-\(size.label)")
                    }
                }
            }
            if let selected {
                ForEach(summary.measurements) { measurement in
                    if let value = selected.measurements[measurement.key], value.isFinite, value > 0 {
                        HStack {
                            Text(label(measurement.key))
                            Spacer()
                            Text("\(number(value)) cm")
                        }
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    }
                }
                if let other = draft.sizes.first(where: { $0.id != selected.id }) {
                    let differences = summary.measurements.compactMap { measurement -> String? in
                        guard let current = selected.measurements[measurement.key], current.isFinite, current > 0,
                              let alternative = other.measurements[measurement.key], alternative.isFinite, alternative > 0 else { return nil }
                        return "\(label(measurement.key)) \(String(format: "%+.1f", alternative - current)) cm"
                    }
                    if !differences.isEmpty {
                        Text("\(selected.label) → \(other.label)\n" + differences.joined(separator: " · "))
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(metrics.value(12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: metrics.value(7)))
                            .accessibilityIdentifier("fitlab-summary-size-difference")
                    }
                }
            }
            Text("단위 cm · 너비는 단면 기준이에요. 나에게 맞는 핏과 추천 사이즈는 내 옷과 비교해 확인할 수 있어요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface, in: RoundedRectangle(cornerRadius: metrics.value(8)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fitlab-product-overview")
    }

    private func readingParagraph(title: String, body: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            Label(title, systemImage: symbol)
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
            Text(body)
                .font(CoorditTypography.gmarketLight(size: metrics.value(13), relativeTo: .body))
                .lineSpacing(metrics.value(6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(metrics.value(14))
        .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: metrics.value(10)))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.value(10))
                .stroke(CoorditFitLabPalette.ink.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func label(_ key: CoorditFitLabMeasurementKey) -> String {
        switch key {
        case .shoulderWidth: "어깨"
        case .chestWidth: "가슴 단면"
        case .totalLength: "총장"
        case .sleeveLength: "소매"
        case .waistWidth: "허리 단면"
        case .hipWidth: "엉덩이 단면"
        case .rise: "밑위"
        case .outseam: "아웃심"
        }
    }
}
#endif
