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
        Button(action: onBack) {
            HStack(spacing: metrics.value(15)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.value(23), weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text(title)
                    .font(CoorditTypography.climate2019(size: metrics.value(22), relativeTo: .headline))
                    .tracking(metrics.value(1.2))
                    .foregroundStyle(Color.black)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.value(26))
            .frame(height: metrics.value(60))
            .frame(maxWidth: .infinity)
            .background(CoorditFitLabPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(6)))
            .shadow(color: .black.opacity(0.05), radius: metrics.value(10), y: metrics.value(4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 뒤로가기")
    }
}

struct CoorditFitLabPrimaryButton: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.climate2010(size: metrics.value(15), relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(36))
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

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .padding(metrics.value(7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CoorditFitLabPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(4)))
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
