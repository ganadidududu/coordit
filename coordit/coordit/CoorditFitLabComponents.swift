import SwiftUI

#if os(iOS)
enum CoorditFitLabPalette {
    static let ink = CoorditDesignTokens.ColorToken.ink
    static let surface = CoorditDesignTokens.ColorToken.panel
    static let field = CoorditDesignTokens.ColorToken.field
    static let empty = CoorditDesignTokens.ColorToken.placeholder
    static let muted = CoorditDesignTokens.ColorToken.fitMuted
}

struct CoorditFitLabTitleCard: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void

    var body: some View {
        CoorditFeatureTitleBar(
            title: title,
            metrics: metrics,
            accessibilityLabel: "\(title) 뒤로가기",
            onBack: onBack
        )
    }
}

struct CoorditFitLabPrimaryButton: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(primaryButtonFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, metrics.value(10))
                .frame(maxWidth: .infinity, minHeight: metrics.value(36))
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 49 / 255, green: 69 / 255, blue: 146 / 255),
                            CoorditFitLabPalette.ink
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))
                .shadow(color: CoorditFitLabPalette.ink.opacity(0.3), radius: metrics.value(6), y: metrics.value(2))
        }
        .buttonStyle(.plain)
    }

    private var primaryButtonFont: Font {
        if dynamicTypeSize.isAccessibilitySize {
            return CoorditTypography.gmarketBold(size: metrics.value(15), relativeTo: .headline)
        }
        return CoorditTypography.climate2010(size: metrics.value(15), relativeTo: .headline)
    }
}

struct CoorditFitLabSourceButton: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(15), relativeTo: .body))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(65))
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 250 / 255, green: 251 / 255, blue: 254 / 255),
                                Color(red: 225 / 255, green: 230 / 255, blue: 243 / 255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        CoorditFitLabSubtleNoise()
                            .opacity(0.38)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.value(7))
                        .stroke(.white.opacity(0.8), lineWidth: metrics.value(1))
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                .shadow(color: .black.opacity(0.12), radius: metrics.value(9), y: metrics.value(4))
        }
        .buttonStyle(.plain)
    }
}

struct CoorditFitLabTexturedPanel: View {
    let cornerRadius: CGFloat
    let intensity: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 90 / 255, green: 104 / 255, blue: 164 / 255),
                    Color(red: 21 / 255, green: 35 / 255, blue: 98 / 255),
                    CoorditFitLabPalette.ink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            CoorditFitLabSubtleNoise()
                .blendMode(.overlay)
                .opacity(0.34 * intensity)

            LinearGradient(
                colors: [.white.opacity(0.26), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CoorditFitLabSubtleNoise: View {
    var body: some View {
        Canvas { context, size in
            let columns = max(Int(size.width), 1)
            let rows = max(Int(size.height), 1)

            for row in stride(from: 0, to: rows, by: 2) {
                for column in stride(from: 0, to: columns, by: 2) {
                    let seed = Double((row * 89 + column * 157) % 1009)
                    let opacity = 0.025 + (sin(seed) + 1) * 0.045
                    let rect = CGRect(x: CGFloat(column), y: CGFloat(row), width: 1, height: 1)
                    context.fill(Path(rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
    }
}

struct CoorditFitLabMannequinPanel: View {
    let assetName: String
    let metrics: CoorditResponsiveMetrics
    var measurements: [CoorditFitLabResultMeasurement] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(metrics.value(7))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                ForEach(measurements) { measurement in
                    if let direction = measurement.direction,
                       let comparison = measurement.comparison,
                       comparison.diff.isFinite {
                        CoorditFitLabOverlayMarker(
                            measurement: measurement,
                            direction: direction,
                            intensity: min(max(abs(comparison.diff) / 5, 0), 1),
                            metrics: metrics
                        )
                        .position(
                            x: proxy.size.width * anchor(for: measurement.key).x,
                            y: proxy.size.height * anchor(for: measurement.key).y
                        )
                    }
                }
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(4)))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(4))
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(assetName == CoorditAssetNames.fitUpper ? "상의 핏 마네킹" : "하의 핏 마네킹")
        .accessibilityIdentifier(
            assetName == CoorditAssetNames.fitUpper
                ? "fitlab-mannequin-upper"
                : "fitlab-mannequin-lower"
        )
    }

    private func anchor(for key: CoorditFitLabMeasurementKey) -> CGPoint {
        switch key {
        case .shoulderWidth: CGPoint(x: 0.50, y: 0.25)
        case .chestWidth: CGPoint(x: 0.50, y: 0.34)
        case .totalLength: CGPoint(x: 0.50, y: 0.56)
        case .sleeveLength: CGPoint(x: 0.76, y: 0.39)
        case .waistWidth: CGPoint(x: 0.50, y: 0.25)
        case .hipWidth: CGPoint(x: 0.50, y: 0.36)
        case .rise: CGPoint(x: 0.50, y: 0.47)
        case .outseam: CGPoint(x: 0.68, y: 0.70)
        }
    }
}

private struct CoorditFitLabOverlayMarker: View {
    let measurement: CoorditFitLabResultMeasurement
    let direction: CoorditFitLabResultMeasurement.Direction
    let intensity: Double
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(spacing: 1) {
            Text(direction.glyph)
                .font(.system(size: metrics.value(13 + CGFloat(intensity) * 3), weight: .black, design: .rounded))
                .frame(width: metrics.value(25 + CGFloat(intensity) * 5), height: metrics.value(22))
                .overlay(
                    Capsule()
                        .stroke(
                            Color.black,
                            style: StrokeStyle(
                                lineWidth: direction == .tight ? 2 : 1.4,
                                dash: direction == .similar ? [3, 2] : []
                            )
                        )
                )
            Text(measurement.title)
                .font(CoorditTypography.gmarketBold(size: metrics.value(7), relativeTo: .caption2))
                .padding(.horizontal, 3)
                .background(Color.white.opacity(0.9), in: Capsule())
        }
        .foregroundStyle(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(measurement.title) \(direction.label), 차이 \(CoorditFitLabResultMeasurement.signed(measurement.comparison?.diff ?? 0)) cm")
        .accessibilityIdentifier("fitlab-overlay-\(measurement.key.rawValue)")
    }
}

struct CoorditFitLabOverlayLegend: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        HStack(spacing: metrics.value(7)) {
            legend("−", "타이트", solid: true)
            legend("≈", "비슷", solid: false)
            legend("+", "여유", solid: true)
        }
        .foregroundStyle(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("마네킹 표시 범례. 마이너스 타이트, 물결 비슷, 플러스 여유")
    }

    private func legend(_ glyph: String, _ label: String, solid: Bool) -> some View {
        HStack(spacing: 2) {
            Text(glyph).fontWeight(.black)
            Text(label)
        }
        .font(CoorditTypography.gmarketMedium(size: metrics.value(7), relativeTo: .caption2))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .overlay(Capsule().stroke(Color.black, style: StrokeStyle(lineWidth: 1, dash: solid ? [] : [2, 2])))
    }
}

struct CoorditFitLabReportCard: View {
    let report: CoorditFitLabReportResponse?
    let fallbackMessage: String?
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(13)) {
            Text("Score Description")
                .font(CoorditTypography.mona12(size: metrics.value(17), relativeTo: .headline))
            if let fallbackMessage {
                Text(fallbackMessage)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(11), relativeTo: .body))
                    .accessibilityIdentifier("fitlab-report-fallback")
            }
            if let report {
                Text(report.report.title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(16), relativeTo: .headline))
                reportText("요약", report.report.summary)
                reportText("추천 근거", report.report.recommendationReason)
                reportText("Fit DNA", report.report.fitDnaSummary)
                ForEach(Array(report.report.measurementAnalysis.enumerated()), id: \.offset) { _, analysis in
                    reportText(analysis.measurement, analysis.text)
                }
                reportText("개인화", report.report.feedbackPersonalization)
                ForEach(Array(report.report.cautions.enumerated()), id: \.offset) { _, caution in
                    reportText("주의", caution)
                }
                ForEach(Array(report.report.nextActions.enumerated()), id: \.offset) { index, action in
                    Text(action)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(index == report.report.nextActions.indices.last ? "fitlab-report-final-action" : "fitlab-report-action-\(index)")
                }
            } else {
                Text("상세 리포트를 불러오지 못했어요. 추천 점수와 비교 수치는 그대로 확인할 수 있어요.")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
            }
        }
        .foregroundStyle(Color.black)
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(7))
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("fitlab-report-description")
    }

    @ViewBuilder
    private func reportText(_ title: String, _ text: String?) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: metrics.value(4)) {
                Text(title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(11), relativeTo: .body))
                Text(text)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityDescription: String {
        guard let report else { return fallbackMessage ?? "상세 리포트 없음" }
        let analysis = report.report.measurementAnalysis.map { "\($0.measurement) \($0.text)" }
        return ([report.report.title, report.report.summary]
            + [report.report.recommendationReason, report.report.fitDnaSummary, report.report.feedbackPersonalization].compactMap { $0 }
            + analysis
            + report.report.cautions
            + report.report.nextActions).joined(separator: " ")
    }
}

struct CoorditFitLabDescriptionCard: View {
    let metrics: CoorditResponsiveMetrics
    let compact: Bool
    let onDetail: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: metrics.value(10)) {
            Text("Score Description")
                .font(CoorditTypography.mona12(size: metrics.value(16), relativeTo: .body))
                .foregroundStyle(Color.black)
            Spacer(minLength: 0)
            if let onDetail {
                Button(action: onDetail) {
                    Text("자세히 보기")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(9), relativeTo: .caption))
                        .foregroundStyle(.white)
                        .frame(width: metrics.value(89), height: metrics.value(28))
                        .background(CoorditFitLabPalette.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, metrics.value(18))
        .padding(.top, compact ? 0 : metrics.value(16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .center : .topLeading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(5)))
    }
}

struct CoorditFitLabStars: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        HStack(spacing: metrics.value(3)) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: metrics.value(15), weight: .semibold))
                    .foregroundStyle(index < 3 ? Color(red: 48 / 255, green: 72 / 255, blue: 151 / 255) : Color.black.opacity(0.14))
            }
        }
    }
}
#endif
