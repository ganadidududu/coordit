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

enum CoorditUsageGuide: String, Identifiable {
    case fitLab, closet
    var id: Self { self }
    var title: String { self == .fitLab ? "핏 랩 사용법" : "옷장 사용법" }
    var steps: [String] {
        switch self {
        case .fitLab: CoorditGarmentCaptureController.featureEnabled
            ? ["상품 링크나 사이즈표 사진을 넣으면 비교로 이어져요.", "옷과 카드를 같은 바닥에 놓고 촬영해요. 자동 인식이 안 되면 사진에서 카드와 옷을 눌러주세요.", "추정 치수를 확인하면 실타래 1개로 비교와 상세 리포트를 봐요. 내 옷의 사진과 치수도 옷장에 저장돼요."]
            : ["상품 링크나 사이즈표 사진을 넣어요.", "비교할 내 옷을 옷장에서 선택해요.", "사이즈별 핏을 비교하고 리포트를 확인해요."]
        case .closet: CoorditGarmentCaptureController.featureEnabled
            ? ["옷과 카드를 같은 바닥에 놓고 촬영해요. 사진에서 골라도 돼요.", "자동 인식이 안 되면 사진에서 카드와 옷을 눌러주세요. 잘못 잡힌 점은 끌어서 맞춰요.", "확인하면 사진과 치수를 함께 저장해요. 다음 비교에 바로 사용할 수 있어요."]
            : ["내 옷의 상품 링크나 사이즈표 사진을 넣어요.", "보유한 사이즈를 골라요.", "옷장에 저장하고 다음 비교에 사용해요."]
        }
    }
}

struct CoorditUsageGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    let guide: CoorditUsageGuide
    let onExample: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(guide.title)
                        .font(CoorditTypography.gmarketBold(size: 22, relativeTo: .title2))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("사용법 닫기")
                    .accessibilityIdentifier("usage-guide-close")
                }
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(CoorditTypography.gmarketBold(size: 13, relativeTo: .caption))
                            .frame(width: 28, height: 28)
                            .background(CoorditFitLabPalette.field, in: Circle())
                        Text(step)
                            .font(CoorditTypography.gmarketMedium(size: 14, relativeTo: .body))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                        onExample()
                    } label: {
                        Label("링크 예시로 따라하기", systemImage: "play.circle")
                    }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 48))
                    .accessibilityIdentifier("usage-guide-example")
                    Text("실타래 차감이나 저장 없이 체험해요.")
                        .font(CoorditTypography.gmarketMedium(size: 11, relativeTo: .caption))
                        .foregroundStyle(CoorditFitLabPalette.muted)
                }
            }
            .padding(24)
        }
        .foregroundStyle(CoorditFitLabPalette.ink)
        .background(CoorditFitLabPalette.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("usage-guide-sheet")
    }
}
#endif
