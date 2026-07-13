import SwiftUI

#if os(iOS)
struct Main01Header: View {
    let scale: CGFloat
    let onProfileTap: (() -> Void)?

    init(scale: CGFloat, onProfileTap: (() -> Void)? = nil) {
        self.scale = scale
        self.onProfileTap = onProfileTap
    }

    var body: some View {
        HStack(spacing: 0) {
            profileIcon
            Spacer(minLength: 0)
            Main01BrandLogo(scale: scale)
            Spacer(minLength: 0)
            headerIcon(assetName: "FigmaTopSun", label: "Weather")
        }
        .frame(
            width: Main01DesignTokens.Metrics.headerWidth * scale,
            height: Main01DesignTokens.Metrics.headerHeight * scale
        )
    }

    @ViewBuilder
    private var profileIcon: some View {
        if let onProfileTap {
            Button(action: onProfileTap) {
                headerIcon(assetName: "FigmaTopMy", label: "My")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My")
        } else {
            headerIcon(assetName: "FigmaTopMy", label: "My")
        }
    }

    private func headerIcon(assetName: String, label: String) -> some View {
        Image(assetName)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(
                width: Main01DesignTokens.Metrics.headerIcon * scale,
                height: Main01DesignTokens.Metrics.headerIcon * scale
            )
            .accessibilityLabel(Text(label))
    }
}

private struct Main01BrandLogo: View {
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            logoText
                .offset(x: 3.159 * scale, y: 9.159 * scale)
            logoTail
                .offset(x: 63.159 * scale, y: 9.159 * scale)
            logoO(assetName: "FigmaLogoO1")
                .offset(x: 26.1815 * scale, y: 12.1851 * scale)
            logoO(assetName: "FigmaLogoO2")
                .offset(x: 45.5812 * scale, y: 12.1851 * scale)
        }
        .frame(
            width: Main01DesignTokens.Metrics.logoWidth * scale,
            height: Main01DesignTokens.Metrics.headerHeight * scale,
            alignment: .topLeading
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("COORDIT"))
    }

    private var logoText: Text {
        Text("C")
            .font(Main01DesignTokens.Typography.logo("2019", size: 22.565 * scale))
            .kerning(-4.513 * scale)
            .foregroundColor(Main01DesignTokens.Colors.foreground)
    }

    private var logoTail: Text {
        let r = Text("R")
            .font(Main01DesignTokens.Typography.logo("2019", size: 22.565 * scale))
            .kerning(-4.513 * scale)
            .foregroundColor(Main01DesignTokens.Colors.foreground)
        let d = Text("D")
            .font(Main01DesignTokens.Typography.logo("2030", size: 23.016 * scale))
            .kerning(-4.1429 * scale)
            .foregroundColor(Main01DesignTokens.Colors.foreground)
        let i = Text("I")
            .font(Main01DesignTokens.Typography.logo("2019", size: 22.565 * scale))
            .kerning(-3.3847 * scale)
            .foregroundColor(Main01DesignTokens.Colors.foreground)
        let t = Text("T")
            .font(Main01DesignTokens.Typography.logo("2019", size: 22.565 * scale))
            .kerning(-4.513 * scale)
            .foregroundColor(Main01DesignTokens.Colors.foreground)
        return Text("\(r)\(d)\(i)\(t)")
    }

    private func logoO(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .renderingMode(.original)
            .frame(width: 18.5032 * scale, height: 14.8932 * scale)
    }
}
#endif
