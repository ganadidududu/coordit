import SwiftUI

#if os(iOS)
enum CoorditSettingsStyle {
    static let ink = CoorditDesignTokens.ColorToken.ink
    static let panel = CoorditDesignTokens.ColorToken.panel
    static let field = CoorditDesignTokens.ColorToken.settingsField
    static let muted = CoorditDesignTokens.ColorToken.muted
    static let line = CoorditDesignTokens.ColorToken.line
    static let danger = CoorditDesignTokens.ColorToken.danger
    static let warmLine = CoorditDesignTokens.ColorToken.warmLine
}

struct CoorditSettingsHeaderCard: View {
    let title: String
    let metrics: CoorditResponsiveMetrics
    let onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: metrics.value(13)) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: metrics.value(17), weight: .bold))
                    .foregroundStyle(CoorditSettingsStyle.ink)
                    .frame(width: metrics.value(28), height: metrics.value(36))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Text(title)
                .font(
                    title == "MY PAGE"
                        ? CoorditTypography.climate2019(size: metrics.value(19), relativeTo: .headline)
                        : CoorditTypography.climate2010(size: metrics.value(17), relativeTo: .headline)
                )
                .foregroundStyle(.black)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.value(14))
        .frame(height: metrics.value(62))
        .frame(maxWidth: .infinity)
        .background(CoorditSettingsStyle.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: metrics.value(12), y: metrics.value(5))
    }
}

struct CoorditSettingsIconTile: View {
    let assetName: String
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        Image(assetName)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .padding(metrics.value(10))
            .frame(width: metrics.value(44), height: metrics.value(44))
            .background(CoorditSettingsStyle.ink)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(12), style: .continuous))
    }
}

struct CoorditSettingsMenuRow: View {
    let title: String
    let subtitle: String
    let assetName: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.value(16)) {
                CoorditSettingsIconTile(assetName: assetName, metrics: metrics)

                VStack(alignment: .leading, spacing: metrics.value(4)) {
                    Text(title)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(16), relativeTo: .headline))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                        .foregroundStyle(CoorditSettingsStyle.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                CoorditSettingsChevron(metrics: metrics)
            }
            .padding(.horizontal, metrics.value(13))
            .frame(height: metrics.value(68))
            .background(CoorditSettingsStyle.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(11), style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: metrics.value(10), y: metrics.value(4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct CoorditSettingsCard<Content: View>: View {
    let metrics: CoorditResponsiveMetrics
    @ViewBuilder let content: Content

    init(metrics: CoorditResponsiveMetrics, @ViewBuilder content: () -> Content) {
        self.metrics = metrics
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, metrics.value(12))
        .frame(maxWidth: .infinity)
        .background(CoorditSettingsStyle.panel)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                .stroke(CoorditSettingsStyle.line.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: metrics.value(9), y: metrics.value(4))
    }
}

struct CoorditSettingsDetailRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let metrics: CoorditResponsiveMetrics
    let titleColor: Color
    let action: (() -> Void)?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        metrics: CoorditResponsiveMetrics,
        titleColor: Color = .black,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.titleColor = titleColor
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: metrics.value(12)) {
            VStack(alignment: .leading, spacing: metrics.value(3)) {
                Text(title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .subheadline))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                        .foregroundStyle(CoorditSettingsStyle.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, metrics.value(13))
        .frame(height: metrics.value(55))
    }
}

struct CoorditSettingsDivider: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        Rectangle()
            .fill(CoorditSettingsStyle.line)
            .frame(height: 1)
            .padding(.leading, metrics.value(13))
    }
}

struct CoorditSettingsChevron: View {
    let metrics: CoorditResponsiveMetrics
    var color: Color = CoorditSettingsStyle.muted

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: metrics.value(14), weight: .semibold))
            .foregroundStyle(color)
            .frame(width: metrics.value(18), height: metrics.value(18))
    }
}

struct CoorditSettingsValuePill: View {
    let text: String
    let metrics: CoorditResponsiveMetrics
    var fill: Color = Color(red: 235 / 255, green: 238 / 255, blue: 244 / 255)
    var foreground: Color = CoorditSettingsStyle.ink

    var body: some View {
        Text(text)
            .font(CoorditTypography.gmarketBold(size: metrics.value(9), relativeTo: .caption))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, metrics.value(10))
            .frame(height: metrics.value(26))
            .background(fill)
            .clipShape(Capsule())
    }
}

struct CoorditSettingsToggle: View {
    @Binding var isOn: Bool
    let metrics: CoorditResponsiveMetrics
    let label: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 0) {
                if isOn {
                    Spacer(minLength: 0)
                }

                Circle()
                    .fill(.white)
                    .frame(width: metrics.value(20), height: metrics.value(20))
                    .shadow(color: .black.opacity(0.16), radius: metrics.value(1.5), y: metrics.value(1))

                if !isOn {
                    Spacer(minLength: 0)
                }
            }
            .padding(metrics.value(2))
            .frame(width: metrics.value(42), height: metrics.value(24))
            .background(isOn ? CoorditSettingsStyle.ink : Color(red: 210 / 255, green: 216 / 255, blue: 225 / 255))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "켜짐" : "꺼짐")
    }
}

struct CoorditSettingsSegment: View {
    let text: String
    let isSelected: Bool
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        Text(text)
            .font(CoorditTypography.gmarketBold(size: metrics.value(8), relativeTo: .caption2))
            .foregroundStyle(isSelected ? .white : CoorditSettingsStyle.muted)
            .padding(.horizontal, metrics.value(9))
            .frame(height: metrics.value(21))
            .background(isSelected ? CoorditSettingsStyle.ink : Color.clear)
            .clipShape(Capsule())
    }
}
#endif
