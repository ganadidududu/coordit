import SwiftUI

#if os(iOS)
struct CoorditMain04Screen: View {
    let onRouteChange: (CoorditFrameRoute) -> Void

    init(onRouteChange: @escaping (CoorditFrameRoute) -> Void = { _ in }) {
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        CoorditScreenScaffold(route: .main04, onRouteChange: onRouteChange, contentTop: 121) { metrics in
            VStack(spacing: metrics.value(16)) {
                CoorditBannerCard(metrics: metrics)

                CoorditFitLabHistoryCard(metrics: metrics, onRouteChange: onRouteChange)

                Spacer(minLength: 0)

                CoorditClosetEntryCard(metrics: metrics) {
                    onRouteChange(.closetOverview)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier("coordit-screen-main04")
        }
    }
}

private struct CoorditBannerCard: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Banner")
                .font(CoorditTypography.gmarketBold(size: metrics.value(13.2), relativeTo: .caption))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.top, metrics.value(17))
                .padding(.leading, metrics.value(11))

            Spacer(minLength: 0)
        }
        .frame(width: metrics.value(361), height: metrics.value(259), alignment: .topLeading)
        .background(CoorditHomePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(10), style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: metrics.value(12), y: metrics.value(4))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("coordit-main04-banner")
    }
}

private struct CoorditFitLabHistoryCard: View {
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: metrics.value(5)) {
                Text("FIT LAB")
                    .font(CoorditTypography.climate2019(size: metrics.value(18.6), relativeTo: .headline))
                    .tracking(-0.93 * metrics.scale)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text("- 당신에게 꼭 맞는 사이즈 설계")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(8.8), relativeTo: .caption2))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, metrics.value(16))
            .padding(.horizontal, metrics.value(16))

            Button {
                onRouteChange(.fitLabInput)
            } label: {
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: Main01DesignTokens.Colors.rgb(3, 14, 68), location: 0.0),
                            .init(color: Main01DesignTokens.Colors.rgb(21, 33, 85), location: 0.56),
                            .init(color: Main01DesignTokens.Colors.rgb(173, 179, 201), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Text("새로운 옷 찾기")
                        .font(CoorditTypography.climate2010(size: metrics.value(8.6), relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(height: metrics.value(24))
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(2.5), style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.value(2.5), style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: metrics.value(0.7))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, metrics.value(5))
            .padding(.horizontal, metrics.value(16))
            .accessibilityIdentifier("coordit-main04-new-fit-button")

            HStack(alignment: .center, spacing: 0) {
                Text("HISTORY")
                    .font(CoorditTypography.climate2019(size: metrics.value(8.8), relativeTo: .caption2))
                    .tracking(-0.35 * metrics.scale)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    onRouteChange(.fitLabHistoryRegister)
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: metrics.value(10), weight: .regular))
                        .foregroundStyle(Main01DesignTokens.Colors.chrome.opacity(0.42))
                        .frame(width: metrics.value(22), height: metrics.value(22))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coordit-main04-history-menu-button")
            }
            .padding(.top, metrics.value(4))
            .padding(.leading, metrics.value(16))
            .padding(.trailing, metrics.value(13))

            Button {
                onRouteChange(.fitLabHistoryDetail)
            } label: {
                Rectangle()
                    .fill(Color.clear)
                    .overlay(
                        Rectangle()
                            .stroke(.black, lineWidth: metrics.value(1))
                    )
                    .frame(width: metrics.value(116), height: metrics.value(77))
            }
            .buttonStyle(.plain)
            .padding(.leading, metrics.value(16))
            .accessibilityIdentifier("coordit-main04-history-card-button")

            Spacer(minLength: 0)
        }
        .frame(width: metrics.value(361), height: metrics.value(170), alignment: .topLeading)
        .background(CoorditHomePalette.card)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(10), style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: metrics.value(12), y: metrics.value(4))
        .accessibilityIdentifier("coordit-main04-fitlab-card")
    }
}

private struct CoorditClosetEntryCard: View {
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("MY CLOSET")
                    .font(CoorditTypography.climate2019(size: metrics.value(17.2), relativeTo: .headline))
                    .tracking(-0.86 * metrics.scale)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.leading, metrics.value(12))

                Spacer(minLength: 0)
            }
            .frame(width: metrics.value(361), height: metrics.value(43))
            .background(
                LinearGradient(
                    colors: [
                        CoorditHomePalette.card,
                        Main01DesignTokens.Colors.rgb(235, 238, 247),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(10), style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: metrics.value(9), y: metrics.value(3))
        }
        .buttonStyle(.plain)
        .padding(.bottom, metrics.value(7))
        .accessibilityIdentifier("coordit-main04-closet-button")
    }
}

private enum CoorditHomePalette {
    static let card = CoorditDesignTokens.ColorToken.panel
}
#endif
