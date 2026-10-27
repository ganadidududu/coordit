import SwiftUI

#if os(iOS)
struct CoorditFitLabGarmentPanel: View {
    let category: CoorditFitLabCategory
    let measurements: [CoorditFitLabResultMeasurement]
    let metrics: CoorditResponsiveMetrics
    @Environment(\.dynamicTypeSize) private var typeSize

    private var visibleMeasurements: [CoorditFitLabResultMeasurement] {
        let keys = category.garmentKind == .upper
            ? CoorditFitLabResultVariant.top : .bottom
        return keys.measurementKeys.filter { category != .skirt || $0 != .rise }.map { key in
            measurements.first { $0.key == key }
                ?? .init(key: key, title: keys.label(for: key), comparison: nil)
        }
    }

    var body: some View {
        VStack(spacing: metrics.value(6)) {
            if typeSize.isAccessibilitySize {
                CoorditFitLabGarmentDrawing(category: category)
                    .frame(height: metrics.value(250))
                ForEach(visibleMeasurements) { callout($0) }
            } else {
                GeometryReader { proxy in
                    let drawing = CoorditFitLabGarmentDrawing(category: category)
                    ZStack {
                        drawing
                        ForEach(Array(visibleMeasurements.enumerated()), id: \.element.id) { index, measurement in
                            let left = index.isMultiple(of: 2)
                            let y: CGFloat = category.garmentKind == .lower
                                ? (index < 2 ? (left ? 0.16 : 0.30) : (left ? 0.49 : category == .shorts ? 0.60 : 0.78))
                                : (index < 2 ? (left ? 0.22 : 0.33) : (left ? 0.68 : 0.73))
                            let end = CGPoint(x: proxy.size.width * (left ? 0.23 : 0.77), y: proxy.size.height * y)
                            let start = drawing.anchor(for: measurement.key, in: proxy.size)
                            let color = markerColor(measurement.direction)
                            Path { path in
                                path.move(to: start)
                                path.addLine(to: CGPoint(x: (start.x + end.x) / 2, y: start.y))
                                path.addLine(to: end)
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                            .accessibilityHidden(true)
                            Circle().fill(color).frame(width: 5, height: 5).position(start)
                                .accessibilityHidden(true)
                            callout(measurement)
                                .frame(width: proxy.size.width * 0.29)
                                .position(end)
                        }
                    }
                }
                .frame(height: metrics.value(category.garmentKind == .lower ? 225 : 205))
            }
            HStack(spacing: metrics.value(10)) {
                legend(.tight)
                legend(.similar)
                legend(.loose)
            }
            if category.garmentKind == .lower {
                Text("\(category.koreanTitle) · 기준 옷과의 실측 차이")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
            }
        }
        .padding(.vertical, metrics.value(8))
        .frame(maxWidth: .infinity)
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(10)))
        .overlay(RoundedRectangle(cornerRadius: metrics.value(10)).stroke(CoorditDesignTokens.ColorToken.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(category.koreanTitle) 핏 마네킹")
        .accessibilityValue(category.rawValue)
        .accessibilityIdentifier(category.garmentKind == .upper ? "fitlab-mannequin-upper" : "fitlab-mannequin-lower")
    }

    private func callout(_ measurement: CoorditFitLabResultMeasurement) -> some View {
        let color = markerColor(measurement.direction)
        return VStack(alignment: .leading, spacing: metrics.value(3)) {
            HStack(spacing: metrics.value(4)) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(measurement.title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(11), relativeTo: .caption))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
            }
            if let comparison = measurement.comparison, let direction = measurement.direction {
                Text("\(CoorditFitLabResultMeasurement.signed(comparison.diff))cm · \(direction.label)")
                    .font(CoorditTypography.gmarketBold(size: metrics.value(11), relativeTo: .caption))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("비교 데이터 없음")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
            }
        }
        .padding(metrics.value(8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: metrics.value(8)))
        .overlay(RoundedRectangle(cornerRadius: metrics.value(8)).stroke(color.opacity(0.65)))
        .shadow(color: color.opacity(0.10), radius: metrics.value(4), y: metrics.value(2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(measurement.title) \(measurement.direction?.label ?? "비교 데이터 없음"), 차이 \(measurement.comparison.map { CoorditFitLabResultMeasurement.signed($0.diff) + " cm" } ?? "없음")")
        .accessibilityIdentifier("fitlab-overlay-\(measurement.key.rawValue)")
    }

    private func legend(_ direction: CoorditFitLabResultMeasurement.Direction) -> some View {
        HStack(spacing: metrics.value(4)) {
            Capsule().fill(markerColor(direction)).frame(width: metrics.value(15), height: metrics.value(4))
            Text(direction.label)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
        }
        .padding(.horizontal, metrics.value(7))
        .padding(.vertical, metrics.value(4))
        .overlay(Capsule().stroke(CoorditDesignTokens.ColorToken.line))
    }

    private func markerColor(_ direction: CoorditFitLabResultMeasurement.Direction?) -> Color {
        switch direction {
        case .tight: CoorditDesignTokens.ColorToken.red
        case .loose: Color(red: 0.10, green: 0.28, blue: 0.96)
        case .similar, nil: CoorditDesignTokens.ColorToken.fitMuted
        }
    }
}

struct CoorditFitLabSizeReason: View {
    let size: CoorditFitLabSizeOption?
    let recommendationReason: String?
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(8)) {
            Text(size?.isRecommended == false ? "ABOUT \(size?.sizeLabel ?? "-")" : "WHY \(size?.sizeLabel ?? "-")?")
                .font(CoorditTypography.gmarketBold(size: metrics.value(20), relativeTo: .headline))
                .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
            Text(size?.isRecommended == true ? (nonemptyReason ?? summary) : summary)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(metrics.value(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditDesignTokens.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(10)))
        .overlay(RoundedRectangle(cornerRadius: metrics.value(10)).stroke(CoorditDesignTokens.ColorToken.line))
        .accessibilityIdentifier("fitlab-size-reason")
    }

    private var nonemptyReason: String? {
        let text = recommendationReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    private var summary: String { size?.comparisonSummary ?? "비교 데이터를 불러오면 부위별 핏을 확인할 수 있어요." }
}

extension CoorditFitLabSizeOption {
    var comparisonSummary: String {
        let descriptions = measurements.compactMap { measurement -> String? in
            guard let direction = measurement.direction else { return nil }
            return "\(measurement.title) \(direction.label)"
        }
        guard !descriptions.isEmpty else { return "이 사이즈의 부위별 실측 비교 데이터가 없어요." }
        return "기준 옷 대비 " + descriptions.joined(separator: " · ")
    }
}
#endif
