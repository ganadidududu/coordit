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
            case .method: "등록 방식 선택하기"
            case .link: "상품 링크 입력하기"
            case .analyze: "링크 분석하기"
            case .size: "내 사이즈 선택하기"
            case .register: "선택한 사이즈 등록하기"
            case .score: "등록한 옷 확인하기"
            }
        }

        var message: String {
            switch self {
            case .add: "잘 맞는 내 옷을 등록하면 다음 핏 비교에 바로 쓸 수 있어요."
            case .method: "내 옷 촬영, 상품 링크, 사이즈표 캡처 중 편한 방법을 골라요. 캡처를 넣으면 내 사이즈를 선택해 등록할 수 있어요."
            case .link: "보유한 옷의 상품 링크를 아래 입력란에 붙여 넣습니다. 옷 종류도 실제 보유한 의류에 맞게 선택합니다."
            case .analyze: "링크 분석하기를 누르면 상품명과 사이즈별 실측 정보를 불러옵니다. 분석이 완료되면 사이즈를 선택합니다."
            case .size: "사이즈표에서 실제로 보유한 옷의 사이즈를 누릅니다. 선택한 사이즈의 실측 정보가 저장됩니다."
            case .register: "선택한 사이즈로 등록하면 내 옷장에 저장돼요. 예시에서는 저장 없이 결과를 볼 수 있어요."
            case .score: "등록한 옷의 치수를 확인해요. 촬영으로 등록한 옷은 사진도 자동으로 들어가요."
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
                if arguments.contains("--coordit-test-closet-tutorial") { step = .add }
#endif
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
            case .closetAddPhoto, .closetAddSizeChart, .closetAddManual: step = .link
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
    let title: String?
    let message: String?
    let canFinish: Bool

    func body(content: Content) -> some View {
        content.modifier(CoorditTutorialTarget(
            isActive: tutorial.step == step,
            progress: "CLOSET 가이드",
            title: title ?? step.title,
            message: message ?? step.message,
            identifier: "closet-tutorial",
            stepIdentifier: "closet-tutorial-step-\(step.rawValue)",
            finishTitle: step == .score && canFinish ? "확인 완료" : nil,
            dismiss: tutorial.dismiss
        ))
    }
}

struct CoorditTutorialTarget: ViewModifier {
    let isActive: Bool
    let progress: String
    let title: String
    let message: String
    let identifier: String
    let stepIdentifier: String
    var finishTitle: String? = nil
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isActive {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(progress)
                            .font(CoorditTypography.gmarketMedium(size: 11))
                        Spacer()
                        Button("도움말 닫기", action: dismiss)
                            .font(CoorditTypography.gmarketMedium(size: 12))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("\(identifier)-dismiss")
                    }
                    Text(title)
                        .font(CoorditTypography.gmarketBold(size: 14))
                    Text(message)
                        .font(CoorditTypography.gmarketMedium(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    if let finishTitle {
                        Button(finishTitle, action: dismiss)
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                            .accessibilityIdentifier("\(identifier)-finish")
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
                .accessibilityIdentifier(stepIdentifier)
            }
            content
                .overlay {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CoorditDesignTokens.ColorToken.ink, lineWidth: 2)
                            .padding(-3)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

extension View {
    func closetTutorialTarget(
        _ step: CoorditClosetTutorial.Step,
        title: String? = nil,
        message: String? = nil,
        canFinish: Bool = false
    ) -> some View {
        modifier(CoorditClosetTutorialTarget(step: step, title: title, message: message, canFinish: canFinish))
    }
}
#endif
