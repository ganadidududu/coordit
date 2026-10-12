import SwiftUI
import Combine

#if os(iOS)
@MainActor
final class CoorditFitLabTutorial: ObservableObject {
    enum Step: Int, CaseIterable {
        case source, link, importLink, review, continueToReferences, references, analyze, result, save

        var title: String {
            switch self {
            case .source: "비교할 상품 불러오기"
            case .link: "상품 링크 입력하기"
            case .importLink: "상품 정보 불러오기"
            case .review: "사이즈표 확인하기"
            case .continueToReferences: "기준 옷 선택으로 이동하기"
            case .references: "나에게 잘 맞는 기준 옷 선택하기"
            case .analyze: "핏 분석 시작하기"
            case .result: "사이즈별 핏 비교하기"
            case .save: "분석 결과 저장하기"
            }
        }

        var message: String {
            switch self {
            case .source: "구매하려는 옷과 내 기준 옷을 비교합니다. 링크로 불러오기를 누릅니다."
            case .link: "상품 페이지 주소를 입력하거나 붙여넣고 다음을 누릅니다. 옷 종류도 상품에 맞게 선택합니다."
            case .importLink: "링크에서 가져오기를 누르면 상품 정보와 사이즈표를 불러옵니다. 아직 분석이나 실타래 사용은 진행되지 않습니다."
            case .review: "위의 상품명과 사이즈별 실측을 확인합니다. 잘못된 값은 수정하고 확인 버튼을 누릅니다."
            case .continueToReferences: "확인한 사이즈표로 비교를 준비합니다. 기준 옷 선택으로 버튼을 누릅니다."
            case .references: "비슷한 종류와 길이의 기준 옷을 한 개 이상 선택합니다. 기준 옷이 없다면 먼저 선택·등록합니다."
            case .analyze: "선택한 기준 옷과 상품의 사이즈를 비교합니다. 핏 분석을 시작하면 실타래 1개가 사용됩니다."
            case .result: "추천 사이즈와 핏 점수를 확인합니다. 아래 사이즈를 누르면 해당 사이즈의 점수와 부위별 차이를 비교할 수 있습니다."
            case .save: "히스토리에 추가를 누르면 리포트를 저장합니다. 확인하기를 누르면 저장하지 않고 Fit Lab으로 돌아갑니다."
            }
        }
    }

    @Published private(set) var step: Step?
    private let defaults: UserDefaults
    private let seenKey = "coordit.fitLabTutorial.v1.seen"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func visitSources() {
        if step != nil { step = .source; return }
        guard !defaults.bool(forKey: seenKey) else { return }
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--coordit-ui-testing") && !arguments.contains("--coordit-test-fitlab-tutorial") { return }
#endif
        step = .source
    }

    func restart() { step = .source }
    func pause() { step = nil }

    func show(_ next: Step) {
        guard step != nil else { return }
        step = next
    }

    func advance(from expected: Step, to next: Step) {
        guard step == expected else { return }
        step = next
    }

    func dismiss() {
        defaults.set(true, forKey: seenKey)
        step = nil
    }
}

private struct CoorditFitLabTutorialTarget: ViewModifier {
    @EnvironmentObject private var tutorial: CoorditFitLabTutorial
    let step: CoorditFitLabTutorial.Step
    let message: String?
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.modifier(CoorditTutorialTarget(
                isActive: enabled && tutorial.step == step,
                progress: "FIT LAB 가이드 · \(step.rawValue + 1)/\(CoorditFitLabTutorial.Step.allCases.count)",
                title: step.title,
                message: message ?? step.message,
                identifier: "fitlab-tutorial",
                stepIdentifier: "fitlab-tutorial-step-\(step.rawValue)",
                dismiss: tutorial.dismiss
            ))
            .id(step)
        } else {
            content
        }
    }
}

private struct CoorditFitLabTutorialScroll: ViewModifier {
    @EnvironmentObject private var tutorial: CoorditFitLabTutorial

    func body(content: Content) -> some View {
        ScrollViewReader { scroll in
            content
                .closetTutorialViewport()
                .task(id: tutorial.step) {
                    guard let step = tutorial.step else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    scroll.scrollTo(step, anchor: .top)
                }
        }
    }
}

extension View {
    func fitLabTutorialTarget(
        _ step: CoorditFitLabTutorial.Step,
        message: String? = nil,
        enabled: Bool = true
    ) -> some View {
        modifier(CoorditFitLabTutorialTarget(step: step, message: message, enabled: enabled))
    }

    func fitLabTutorialScroll() -> some View { modifier(CoorditFitLabTutorialScroll()) }
}
#endif
