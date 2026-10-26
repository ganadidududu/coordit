import SwiftUI

#if os(iOS)
struct CoorditFitLabProductOverview: View {
    let draft: CoorditFitLabDraft
    let metrics: CoorditResponsiveMetrics
    @State private var selectedSizeID: UUID?
    private var selected: CoorditFitLabSizeDraft? { draft.sizes.first { $0.id == selectedSizeID } ?? draft.sizes.first }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(12)) {
            Text(draft.productName)
                .font(CoorditTypography.gmarketBold(size: metrics.value(19), relativeTo: .title3))
            DisclosureGroup("상품 사이즈 보기") {
            Text("단위 cm")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(CoorditFitLabPalette.muted)
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
                ForEach(CoorditFitLabMeasurementKey.allCases.filter { $0.garmentKind == draft.garmentKind }, id: \.self) { key in
                    if let value = selected.measurements[key] {
                        HStack {
                            Text(label(key))
                            Spacer()
                            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) cm")
                        }
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    }
                }
            }
            if draft.sizes.count > 1, let selected, let next = draft.sizes.first(where: { $0.id != selected.id }) {
                let differences = [CoorditFitLabMeasurementKey.chestWidth, .totalLength, .waistWidth, .outseam].compactMap { key -> String? in
                    guard let current = selected.measurements[key], let alternative = next.measurements[key] else { return nil }
                    return "\(label(key)) \(String(format: "%+.1f", alternative - current)) cm"
                }
                if !differences.isEmpty {
                    Text("\(selected.label) → \(next.label): " + differences.joined(separator: " · "))
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            }
            .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
            .tint(CoorditFitLabPalette.ink)
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface, in: RoundedRectangle(cornerRadius: metrics.value(8)))
        .accessibilityIdentifier("fitlab-product-overview")
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
