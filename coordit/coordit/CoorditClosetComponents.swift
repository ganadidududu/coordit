import SwiftUI
import UIKit

#if os(iOS)
enum CoorditClosetColors {
    static let navy = CoorditDesignTokens.ColorToken.ink
    static let card = CoorditDesignTokens.ColorToken.panel
    static let field = CoorditDesignTokens.ColorToken.closetField
    static let muted = CoorditDesignTokens.ColorToken.closetMuted
    static let blue = CoorditDesignTokens.ColorToken.blue
    static let cyan = CoorditDesignTokens.ColorToken.cyan
    static let green = CoorditDesignTokens.ColorToken.green
    static let red = CoorditDesignTokens.ColorToken.red
}

struct CoorditClosetTitleBar: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: metrics.value(18)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.value(25), weight: .bold))
                Text(title)
                    .font(CoorditTypography.climate2019(size: metrics.value(22)))
                    .tracking(metrics.value(1.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, metrics.value(29))
            .frame(height: metrics.value(60))
            .background(CoorditClosetColors.card)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct CoorditClosetSegment: View {
    let selected: CoorditClosetCategory
    let metrics: CoorditResponsiveMetrics
    let onSelect: (CoorditClosetCategory) -> Void

    var body: some View {
        HStack(spacing: metrics.value(7)) {
            segment(.top)
            segment(.bottom)
        }
        .padding(metrics.value(5))
        .background(CoorditClosetColors.field)
        .clipShape(Capsule())
    }

    private func segment(_ category: CoorditClosetCategory) -> some View {
        Button {
            onSelect(category)
        } label: {
            Text(category.title)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11)))
                .foregroundStyle(selected == category ? .white : CoorditClosetColors.navy)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(28))
                .background(selected == category ? CoorditClosetColors.navy : .white.opacity(0.65))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CoorditClosetMetricTile: View {
    let value: String
    let label: String
    let color: Color
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(3)) {
            Text(value)
                .font(CoorditTypography.gmarketBold(size: metrics.value(16)))
                .foregroundStyle(color)
            Text(label)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(8)))
                .foregroundStyle(CoorditClosetColors.navy.opacity(0.46))
        }
        .padding(.horizontal, metrics.value(9))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: metrics.value(51))
        .background(CoorditClosetColors.field)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
    }
}

struct CoorditClosetPrimaryButton: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.climate2010(size: metrics.value(17)))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(height))
                .background(
                    LinearGradient(
                        colors: [
                            CoorditClosetColors.navy,
                            Color(red: 47 / 255, green: 66 / 255, blue: 142 / 255),
                            CoorditClosetColors.navy,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                .shadow(color: CoorditClosetColors.navy.opacity(0.35), radius: metrics.value(6), y: metrics.value(2))
        }
        .buttonStyle(.plain)
    }
}

struct CoorditClosetGarmentCard: View {
    let item: CoorditClosetItem
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: metrics.value(3)) {
                CoorditClosetGarmentArtwork(imageData: item.imageData, metrics: metrics)
                    .frame(height: metrics.value(42))
                HStack(alignment: .firstTextBaseline, spacing: metrics.value(6)) {
                    Text(item.category.title)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(6)))
                        .foregroundStyle(item.category == .top ? CoorditClosetColors.blue : .white)
                        .padding(.horizontal, metrics.value(6))
                        .frame(height: metrics.value(13))
                        .background(item.category == .top ? Color(red: 226 / 255, green: 232 / 255, blue: 242 / 255) : CoorditClosetColors.navy)
                        .clipShape(Capsule())
                    Text(item.name)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(12)))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                HStack(alignment: .firstTextBaseline, spacing: metrics.value(4)) {
                    Text("\(item.score)")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(15)))
                        .foregroundStyle(item.scoreColor)
                    Text("fit score")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(7.5)))
                        .foregroundStyle(CoorditClosetColors.navy.opacity(0.48))
                }
            }
            .padding(metrics.value(6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CoorditClosetColors.card)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.name)
    }
}

struct CoorditClosetGarmentArtwork: View {
    let imageData: Data?
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 226 / 255, green: 230 / 255, blue: 238 / 255),
                    Color(red: 239 / 255, green: 242 / 255, blue: 247 / 255),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "tshirt")
                    .font(.system(size: metrics.value(22), weight: .medium))
                    .foregroundStyle(CoorditClosetColors.navy.opacity(0.18))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(8))
                .stroke(Color(red: 213 / 255, green: 219 / 255, blue: 231 / 255), lineWidth: metrics.value(0.7))
        )
    }
}
#endif
