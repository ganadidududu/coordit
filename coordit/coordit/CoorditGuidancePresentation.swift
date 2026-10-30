import SwiftUI

#if os(iOS)
enum CoorditGuidanceStyle {
    static let background = CoorditDesignTokens.ColorToken.ink
    static let accent = CoorditDesignTokens.ColorToken.loadingSparkle
    static let inset: CGFloat = 16
    static let radius: CGFloat = 12
    static let title: CGFloat = 17
    static let body: CGFloat = 15
    static let caption: CGFloat = 12
}

extension CoorditUsageGuide {
    var practiceTitle: String {
        self == .closet ? "옷장 등록, 예시로 함께 해볼까요?" : "핏랩, 예시로 함께 해볼까요?"
    }

    var practiceSteps: [String] {
        self == .closet
            ? ["내 옷 링크 불러오기", "보유한 사이즈 선택하기", "내 옷장에 등록하기"]
            : ["상품 링크 불러오기", "무료 리포트 확인하기", "내 옷을 골라 비교하기"]
    }
}

struct CoorditGuidanceIntroduction: View {
    let guide: CoorditUsageGuide
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("처음 이용 안내")
                    .font(CoorditTypography.gmarketBold(size: 14, relativeTo: .headline))
                    .foregroundStyle(CoorditGuidanceStyle.accent)
                    .padding(12)
                    .background(CoorditGuidanceStyle.background, in: Capsule())
                Text(guide.practiceTitle)
                    .font(CoorditTypography.gmarketBold(size: 22, relativeTo: .title2))
                    .fixedSize(horizontal: false, vertical: true)
                Text("처음에는 준비된 예시로 사용법을 익혀요.\n화면의 안내를 따라 직접 눌러보세요.")
                    .font(CoorditTypography.gmarketMedium(size: 17, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(guide.practiceSteps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(CoorditTypography.gmarketBold(size: 14, relativeTo: .headline))
                                .frame(width: 30, height: 30)
                                .background(CoorditDesignTokens.ColorToken.placeholder, in: Circle())
                                .accessibilityHidden(true)
                            Text(step)
                                .accessibilityIdentifier("practice-intro-step-\(index + 1)")
                                .font(CoorditTypography.gmarketMedium(size: 15, relativeTo: .body))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(CoorditGuidanceStyle.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CoorditDesignTokens.ColorToken.field, in: RoundedRectangle(cornerRadius: CoorditGuidanceStyle.radius))
                Text("실제 저장·실타래 사용 없이 연습해요.")
                    .font(CoorditTypography.gmarketMedium(size: 15, relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("안내 시작하기", action: onStart)
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 48))
                    .accessibilityIdentifier("practice-intro-start")
                Button("나중에 할게요", action: onLater)
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary, height: 48))
                    .accessibilityIdentifier("practice-intro-later")
                Text("상단 ‘사용법’에서 언제든 다시 시작할 수 있어요.")
                    .font(CoorditTypography.gmarketMedium(size: 12, relativeTo: .caption))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(CoorditDesignTokens.ColorToken.panel)
        }
        .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
        .background(CoorditDesignTokens.ColorToken.panel)
        .presentationDetents([.height(620), .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practice-introduction")
    }
}
#endif
