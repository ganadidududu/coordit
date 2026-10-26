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
            case .continueToReferences: "기준 옷 선택으로 이동하기"
            case .references: "나에게 잘 맞는 기준 옷 선택하기"
            case .analyze: "핏 분석 시작하기"
            case .result: "사이즈별 핏 비교하기"
            case .save: "분석 결과 저장하기"
            }
        }

        var message: String {
            switch self {
            case .source: "구매할 옷의 링크나 사이즈표 사진을 넣어주세요."
            case .link: "상품 페이지 주소를 입력하거나 붙여넣고 다음을 누릅니다. 옷 종류도 상품에 맞게 선택합니다."
            case .importLink: "다음을 누르면 사이즈표를 불러와 바로 비교로 이어져요."
            case .review: "누락되거나 잘못 읽힌 값만 수정해주세요. 정상적으로 읽힌 사이즈표는 바로 넘어가요."
            case .continueToReferences: "확인한 사이즈표로 비교를 준비합니다. 기준 옷 선택으로 버튼을 누릅니다."
            case .references: "비교할 내 옷을 골라주세요. 예시에서는 준비된 옷을 선택하면 돼요."
            case .analyze: "선택한 내 옷과 상품의 사이즈를 비교해요. 예시 체험에서는 실타래를 사용하지 않아요."
            case .result: "추천 사이즈와 핏 점수를 확인합니다. 아래 사이즈를 누르면 해당 사이즈의 점수와 부위별 차이를 비교할 수 있습니다."
            case .save: "실제 분석은 히스토리에 추가해 다시 볼 수 있어요. 예시는 체험 마치기로 끝내요."
            }
        }
    }

    @Published private(set) var step: Step?
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
                progress: "FIT LAB 가이드",
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

extension View {
    func fitLabTutorialTarget(
        _ step: CoorditFitLabTutorial.Step,
        message: String? = nil,
        enabled: Bool = true
    ) -> some View {
        modifier(CoorditFitLabTutorialTarget(step: step, message: message, enabled: enabled))
    }

}
#endif
