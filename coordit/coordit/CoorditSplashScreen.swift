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
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .contentShape(Rectangle())
        .onTapGesture {
            onRouteChange(.main04)
        }
        .accessibilityAction {
            onRouteChange(.main04)
        }
        .accessibilityIdentifier("coordit-screen-splash")
    }
}

private struct CoorditSplashBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let metrics = CoorditResponsiveMetrics(size: geometry.size)

            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Main01DesignTokens.Colors.rgb(12, 23, 82), location: 0.0),
                        .init(color: Main01DesignTokens.Colors.rgb(17, 30, 90), location: 0.20),
                        .init(color: Main01DesignTokens.Colors.rgb(0, 12, 64), location: 0.50),
                        .init(color: Main01DesignTokens.Colors.rgb(103, 113, 150), location: 0.79),
                        .init(color: Main01DesignTokens.Colors.rgb(247, 248, 248), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        .white.opacity(0.0),
                        .white.opacity(0.07),
                        .white.opacity(0.23),
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 260
                )
                .blendMode(.screen)

                Canvas { context, size in
                    let columns = max(Int(size.width), 1)
                    let rows = max(Int(size.height), 1)

                    for row in 0..<rows {
                        for column in 0..<columns {
                            let seed = Double((row * 97 + column * 193) % 1223)
                            let verticalBias = 1 - min(Double(row) / max(Double(rows), 1), 1)
                            let opacity = 0.012 + (sin(seed) + 1) * 0.024 + verticalBias * 0.028
                            let rect = CGRect(x: CGFloat(column), y: CGFloat(row), width: 0.72, height: 0.72)
                            context.fill(Path(rect), with: .color(.white.opacity(opacity)))
                        }
                    }
                }
                .blendMode(.overlay)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.58), location: 0.0),
                        .init(color: .black.opacity(0.22), location: 0.018),
                        .init(color: .clear, location: 0.070),
                        .init(color: .clear, location: 0.930),
                        .init(color: .black.opacity(0.22), location: 0.982),
                        .init(color: .black.opacity(0.58), location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                RoundedRectangle(cornerRadius: metrics.value(54), style: .continuous)
                    .stroke(.black.opacity(0.50), lineWidth: metrics.value(4))
                    .blur(radius: metrics.value(0.45))
                    .padding(metrics.value(1.2))
            }
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
