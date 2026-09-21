import SwiftUI
import Combine

#if os(iOS)
@MainActor
final class CoorditClosetTutorial: ObservableObject {
    enum Step: Int {
        case add, method, link, analyze, size, register, score

        var title: String {
            switch self {
            case .add: "보유 의류 추가하기"
            case .method: "링크로 불러오기"
            case .link: "상품 링크 입력하기"
            case .analyze: "링크 분석하기"
            case .size: "내 사이즈 선택하기"
            case .register: "선택한 사이즈 등록하기"
            case .score: "핏 스코어 확인하기"
            }
        }

        var message: String {
            switch self {
            case .add: "보유 의류 추가하기 버튼으로 내 옷을 등록합니다. 등록한 옷 중 기준 의류로 선택한 데이터가 나의 ‘100점 핏 사이즈’ 계산에 반영됩니다."
            case .method: "링크로 불러오기를 누르면 상품 페이지에서 의류 정보와 사이즈표를 가져옵니다."
            case .link: "보유한 옷의 상품 링크를 아래 입력란에 붙여 넣습니다. 옷 종류도 실제 보유한 의류에 맞게 선택합니다."
            case .analyze: "링크 분석하기를 누르면 상품명과 사이즈별 실측 정보를 불러옵니다. 분석이 완료되면 사이즈를 선택합니다."
            case .size: "사이즈표에서 실제로 보유한 옷의 사이즈를 누릅니다. 선택한 사이즈의 실측 정보가 저장됩니다."
            case .register: "선택한 사이즈로 등록을 누르면 이 옷을 Closet에 저장합니다. 저장이 완료되면 핏 스코어를 확인합니다."
            case .score: "등록한 의류의 핏 스코어입니다. 나에게 잘 맞는 옷을 기준 의류로 선택하면, 그 실측 데이터로 ‘100점 핏 사이즈’를 계산합니다."
            }
        }
    }

    @Published private(set) var step: Step?
    private let defaults: UserDefaults
    private let seenKey = "coordit.closetTutorial.v1.seen"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func visit(_ route: CoorditFrameRoute, draft: CoorditClosetDraft) {
        if route == .closetOverview {
            if step != nil {
                step = .add
            } else if !defaults.bool(forKey: seenKey) {
#if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--coordit-ui-testing") && !arguments.contains("--coordit-test-closet-tutorial") { return }
#endif
                step = .add
            }
        } else if step != nil {
            switch route {
            case .closetAddMethod: step = .method
            case .closetAddLink:
                if !draft.extractedSizeRows.isEmpty {
                    step = draft.selectedSizeRow == nil ? .size : .register
                } else {
                    updateLink(draft.productLink)
                }
            case .closetAddPhoto, .closetAddManual: step = nil
            default: break
            }
        }
    }

    func restart() { step = .add }

    func advance(from expected: Step, to next: Step) {
        guard step == expected else { return }
        step = next
    }

    func updateLink(_ text: String) {
        guard step == .method || step == .link || step == .analyze else { return }
        let url = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        let valid = ["http", "https"].contains(url?.scheme?.lowercased() ?? "") && !(url?.host?.isEmpty ?? true)
        step = valid ? .analyze : .link
    }

    func dismiss() {
        defaults.set(true, forKey: seenKey)
        step = nil
    }
}

private struct CoorditClosetTutorialTarget: ViewModifier {
    @EnvironmentObject private var tutorial: CoorditClosetTutorial
    let step: CoorditClosetTutorial.Step
    let message: String?
    let canFinish: Bool

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if tutorial.step == step {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CLOSET 가이드 · \(step.rawValue + 1)/7")
                            .font(CoorditTypography.gmarketMedium(size: 11))
                        Spacer()
                        Button("나중에", action: tutorial.dismiss)
                            .font(CoorditTypography.gmarketMedium(size: 12))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("closet-tutorial-dismiss")
                    }
                    Text(step.title)
                        .font(CoorditTypography.gmarketBold(size: 14))
                    Text(message ?? step.message)
                        .font(CoorditTypography.gmarketMedium(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    if step == .score && canFinish {
                        Button("핏 스코어 확인 완료", action: tutorial.dismiss)
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                            .accessibilityIdentifier("closet-tutorial-finish")
                    }
                    Image(systemName: "arrow.down")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
                .padding(16)
                .background(CoorditDesignTokens.ColorToken.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(CoorditDesignTokens.ColorToken.line, lineWidth: 1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("closet-tutorial-step-\(step.rawValue)")
            }
            content
                .overlay {
                    if tutorial.step == step {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CoorditDesignTokens.ColorToken.ink, lineWidth: 2)
                            .padding(-3)
                            .allowsHitTesting(false)
                    }
                }
        }
        .anchorPreference(key: CoorditClosetSpotlightKey.self, value: .bounds) { anchor in
            CoorditClosetSpotlightBounds(target: tutorial.step == step ? anchor : nil)
        }
    }
}

struct CoorditClosetSpotlightBounds {
    var target: Anchor<CGRect>?
    var viewport: Anchor<CGRect>?
}

struct CoorditClosetSpotlightKey: PreferenceKey {
    static var defaultValue: CoorditClosetSpotlightBounds { CoorditClosetSpotlightBounds() }

    static func reduce(value: inout CoorditClosetSpotlightBounds, nextValue: () -> CoorditClosetSpotlightBounds) {
        let next = nextValue()
        if let target = next.target { value.target = target }
        if let viewport = next.viewport { value.viewport = viewport }
    }
}

struct CoorditClosetSpotlight: View {
    let bounds: CoorditClosetSpotlightBounds

    var body: some View {
        GeometryReader { proxy in
            if let target = bounds.target, let viewport = bounds.viewport {
                let screen = CGRect(origin: .zero, size: proxy.size)
                let navHeight = Main01DesignTokens.Metrics.navHeight * proxy.size.width / 402
                let visibleContent = proxy[viewport].intersection(
                    CGRect(x: 0, y: 0, width: screen.width, height: max(0, screen.height - navHeight))
                )
                let spotlight = proxy[target].insetBy(dx: -6, dy: -6).intersection(visibleContent)
                Path { path in
                    path.addRect(screen)
                    if !spotlight.isNull && !spotlight.isEmpty {
                        path.addRoundedRect(in: spotlight, cornerSize: CGSize(width: 10, height: 10))
                    }
                }
                .fill(Color.black.opacity(0.26), style: FillStyle(eoFill: true))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func closetTutorialViewport() -> some View {
        transformAnchorPreference(key: CoorditClosetSpotlightKey.self, value: .bounds) { bounds, anchor in
            bounds.viewport = anchor
        }
    }

    func closetTutorialTarget(
        _ step: CoorditClosetTutorial.Step,
        message: String? = nil,
        canFinish: Bool = false
    ) -> some View {
        modifier(CoorditClosetTutorialTarget(step: step, message: message, canFinish: canFinish))
    }
}
#endif

#if os(iOS)
struct ClosetLinkMethodTutorialModifier: ViewModifier {
    let isLink: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isLink {
            content.closetTutorialTarget(.method)
        } else {
            content
        }
    }
}
#endif
