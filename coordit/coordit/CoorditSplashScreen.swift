import SwiftUI

#if os(iOS)
struct CoorditSplashScreen: View {
    let onRouteChange: (CoorditFrameRoute) -> Void

    init(onRouteChange: @escaping (CoorditFrameRoute) -> Void = { _ in }) {
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = CoorditResponsiveMetrics(size: geometry.size)

            ZStack {
                CoorditSplashBackground()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: metrics.value(232))

                    Text("당신을 위한 디지털 옷장")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(24.462), relativeTo: .title2))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .accessibilityIdentifier("coordit-splash-tagline")

                    Rectangle()
                        .fill(.white.opacity(0.92))
                        .frame(width: max(metrics.value(0.8), 0.5), height: metrics.value(100))
                        .padding(.top, metrics.value(48))

                    CoorditSplashLogo(scale: metrics.scale)
                        .frame(width: metrics.value(199.032), height: metrics.value(55.574))
                        .padding(.top, metrics.value(35))
                        .accessibilityIdentifier("coordit-splash-logo")

                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    onRouteChange(.main04)
                }
                .accessibilityAction {
                    onRouteChange(.main04)
                }
                .accessibilityIdentifier("coordit-screen-splash")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Button("로그인/회원가입") {
                    onRouteChange(.myPageAccount)
                }
                .font(CoorditTypography.gmarketMedium(size: metrics.value(16), relativeTo: .headline))
                .foregroundStyle(Main01DesignTokens.Colors.chrome)
                .frame(
                    width: signupButtonWidth(for: geometry.size),
                    height: signupButtonHeight(for: metrics)
                )
                .background(
                    Main01DesignTokens.Colors.surface,
                    in: RoundedRectangle(cornerRadius: metrics.value(14), style: .continuous)
                )
                .shadow(
                    color: Main01DesignTokens.Colors.chrome.opacity(0.16),
                    radius: metrics.value(16),
                    y: metrics.value(8)
                )
                .buttonStyle(.plain)
                .padding(.bottom, geometry.safeAreaInsets.bottom + metrics.value(30))
                .accessibilityIdentifier("splash-signup-entry")
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    private func signupButtonWidth(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.52, 168), 228)
    }

    private func signupButtonHeight(for metrics: CoorditResponsiveMetrics) -> CGFloat {
        min(max(metrics.value(52), 48), 58)
    }
}

private struct CoorditSplashBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image(CoorditAssetNames.splashReference)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .background(Main01DesignTokens.Colors.chrome)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CoorditSplashLogo: View {
    let scale: CGFloat

    var body: some View {
        let logoScale = scale * 1.432

        ZStack(alignment: .topLeading) {
            logoText(sizeScale: logoScale)
                .offset(x: 3.159 * logoScale, y: 9.159 * logoScale)

            logoTail(sizeScale: logoScale)
                .offset(x: 63.159 * logoScale, y: 9.159 * logoScale)

            logoO(assetName: "FigmaLogoO1", sizeScale: logoScale)
                .offset(x: 26.1815 * logoScale, y: 12.1851 * logoScale)

            logoO(assetName: "FigmaLogoO2", sizeScale: logoScale)
                .offset(x: 45.5812 * logoScale, y: 12.1851 * logoScale)
        }
        .frame(
            width: 139 * logoScale,
            height: 38.8087 * logoScale,
            alignment: .topLeading
        )
        .offset(x: 4.08 * logoScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("COORDIT"))
    }

    private func logoText(sizeScale: CGFloat) -> Text {
        Text("C")
            .font(CoorditTypography.climate2019(size: 22.565 * sizeScale, relativeTo: .title))
            .kerning(-4.513 * sizeScale)
            .foregroundColor(.white)
    }

    private func logoTail(sizeScale: CGFloat) -> Text {
        let r = Text("R")
            .font(CoorditTypography.climate2019(size: 22.565 * sizeScale, relativeTo: .title))
            .kerning(-4.513 * sizeScale)
            .foregroundColor(.white)
        let d = Text("D")
            .font(CoorditTypography.climate2030(size: 23.016 * sizeScale, relativeTo: .title))
            .kerning(-4.1429 * sizeScale)
            .foregroundColor(.white)
        let i = Text("I")
            .font(CoorditTypography.climate2019(size: 22.565 * sizeScale, relativeTo: .title))
            .kerning(-3.3847 * sizeScale)
            .foregroundColor(.white)
        let t = Text("T")
            .font(CoorditTypography.climate2019(size: 22.565 * sizeScale, relativeTo: .title))
            .kerning(-4.513 * sizeScale)
            .foregroundColor(.white)
        return Text("\(r)\(d)\(i)\(t)")
    }

    private func logoO(assetName: String, sizeScale: CGFloat) -> some View {
        Image(assetName)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.white)
            .frame(width: 18.5032 * sizeScale, height: 14.8932 * sizeScale)
    }
}
#endif
