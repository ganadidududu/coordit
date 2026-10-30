import SwiftUI
import Combine

#if os(iOS)
@MainActor
final class CoorditFitLabTutorial: ObservableObject {
    enum Step: Int, CaseIterable {
        case source, link, importLink, review, continueToReferences, references, analyze, result, save

        var title: String {
            switch self {
            case .source: "입력 방식 선택하기"
            case .link: "상품 링크 입력하기"
            case .importLink: "상품 정보 불러오기"
            case .review: "읽지 못한 값 보완하기"
            case .continueToReferences: "무료 분석 확인하고 비교하기"
            case .references: "나에게 잘 맞는 기준 옷 선택하기"
            case .analyze: "핏 분석 시작하기"
            case .result: "사이즈별 핏 비교하기"
            case .save: "분석 결과 저장하기"
            }
        }

        var message: String {
            switch self {
            case .source: "상품 링크로 시작하는 걸 추천해요. 링크가 없으면 사이즈표 캡처를 선택해주세요. 불러오지 못하면 직접 입력으로 이어갈 수 있어요."
            case .link: "상품 페이지 주소를 입력하거나 붙여넣고 다음을 누릅니다. 옷 종류도 상품에 맞게 선택합니다."
            case .importLink: "다음을 누르면 링크의 상품과 사이즈 정보를 무료로 정리해요."
            case .review: "누락되거나 잘못 읽힌 값만 수정해주세요. 정상적으로 읽힌 사이즈표는 바로 넘어가요."
            case .continueToReferences: "리포트를 확인하세요.\n‘내 옷과 비교하기’ 버튼을 눌러보세요."
            case .references: "‘옷장에서 골라 비교’를 누르고, 방금 등록한 예시 옷을 선택해주세요."
            case .analyze: "선택한 내 옷과 상품의 사이즈를 비교해요. 예시 체험에서는 실타래를 사용하지 않아요."
            case .result: "추천 사이즈와 핏 점수를 확인합니다. 아래 사이즈를 누르면 해당 사이즈의 점수와 부위별 차이를 비교할 수 있습니다."
            case .save: "실제 분석은 히스토리에 추가해 다시 볼 수 있어요. 예시는 체험 마치기로 끝내요."
            }
        }
    }

    @Published private(set) var step: Step?
    @Published private(set) var completionRevision = 0
    var requiresSkipConfirmation = false
    private let defaults: UserDefaults
    private let seenKey = "coordit.fitLabTutorial.v1.seen"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func visitSources() {
        if step != nil { step = .source; return }
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--coordit-test-fitlab-tutorial") { step = .source }
#endif
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
        completionRevision += 1
    }
}

private struct CoorditFitLabTutorialTarget: ViewModifier {
    @EnvironmentObject private var tutorial: CoorditFitLabTutorial
    let step: CoorditFitLabTutorial.Step
    let title: String?
    let message: String?
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.modifier(CoorditTutorialTarget(
                isActive: enabled && tutorial.step == step,
                progress: [CoorditFitLabTutorial.Step.source, .link, .importLink].contains(step) ? "1/3 · 상품 링크"
                    : ([CoorditFitLabTutorial.Step.review, .continueToReferences].contains(step) ? "2/3 · 무료 리포트" : "3/3 · 내 옷과 비교"),
                title: title ?? step.title,
                message: message ?? step.message,
                identifier: "fitlab-tutorial",
                stepIdentifier: "fitlab-tutorial-step-\(step.rawValue)",
                requiresSkipConfirmation: tutorial.requiresSkipConfirmation,
                dismiss: tutorial.dismiss
            ))
            .id(step)
        } else {
            content
        }
    }
}

extension View {
    func fitLabTutorialTarget(
        _ step: CoorditFitLabTutorial.Step,
        title: String? = nil,
        message: String? = nil,
        enabled: Bool = true
    ) -> some View {
        modifier(CoorditFitLabTutorialTarget(step: step, title: title, message: message, enabled: enabled))
    }

}
#endif
