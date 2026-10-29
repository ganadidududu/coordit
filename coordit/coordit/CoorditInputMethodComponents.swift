import SwiftUI

#if os(iOS)
enum CoorditSizeChartCopy {
    static let title = "사이즈표 사진 넣기"
    static let subtitle = "캡처에서 치수를 읽어요"
    static let heading = "사이즈표 이미지 가져오기"
    static let instruction = "사이즈표가 보이는 캡처를 선택해주세요."
    static let choosePhoto = "사진에서 선택"
    static let camera = "카메라로 촬영"
}

struct CoorditInputMethodPanel<Content: View>: View {
    let metrics: CoorditResponsiveMetrics
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: metrics.value(8), content: content)
            .padding(metrics.value(8))
            .background(CoorditFitLabTexturedPanel(cornerRadius: metrics.value(8), intensity: 1))
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
    }
}

struct CoorditInputMethodCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.value(11)) {
                Image(systemName: symbol)
                    .font(.system(size: metrics.value(19), weight: .semibold))
                    .foregroundStyle(CoorditFitLabPalette.ink)
                    .frame(width: metrics.value(36), height: metrics.value(36))
                    .background(CoorditFitLabPalette.field.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                VStack(alignment: .leading, spacing: metrics.value(3)) {
                    Text(title)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                        .foregroundStyle(Color.black)
                    Text(subtitle)
                        .font(CoorditTypography.gmarketLight(size: metrics.value(11), relativeTo: .caption))
                        .foregroundStyle(Color.black.opacity(0.58))
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: metrics.value(60), alignment: .leading)
            .padding(.horizontal, metrics.value(12))
            .padding(.vertical, metrics.value(7))
            .background(LinearGradient(colors: [.white, CoorditFitLabPalette.empty], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
            .overlay(RoundedRectangle(cornerRadius: metrics.value(7)).stroke(.white.opacity(0.85), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: metrics.value(7), y: metrics.value(3))
        }
        .buttonStyle(.plain)
        .coorditPressFeedback()
        .accessibilityLabel(title)
    }
}

#endif
