import SwiftUI

#if os(iOS)
struct CoorditGlobalFitAnalysisBanner: View {
    @ObservedObject var coordinator: CoorditFitLabCoordinator
    let onOpenResult: (CoorditFrameRoute) -> Void
    let onOpenFitLab: () -> Void
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @GestureState private var dismissOffset: CGFloat = 0

    var body: some View {
        Group {
            if coordinator.isAnalysisNoticeVisible {
                switch coordinator.analysisState {
                case .idle:
                    EmptyView()
                case .running:
                    banner {
                        ProgressView()
                            .tint(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("핏 리포트를 계산하고 있어요")
                                .font(CoorditTypography.gmarketBold(size: 12))
                            Text("다른 탭을 둘러봐도 계산은 계속됩니다.")
                                .font(CoorditTypography.gmarketMedium(size: 9))
                                .opacity(0.76)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityIdentifier("global-fit-analysis-running")
                case .completed(let route):
                    Button {
                        onOpenResult(route)
                        coordinator.dismissAnalysisNotice()
                    } label: {
                        banner {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("핏 리포트가 완성됐어요")
                                    .font(CoorditTypography.gmarketBold(size: 12))
                                Text("눌러서 결과를 확인하세요.")
                                    .font(CoorditTypography.gmarketMedium(size: 9))
                                    .opacity(0.76)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .coorditPressFeedback()
                    .accessibilityIdentifier("global-fit-analysis-completed")
                case .failed(let message):
                    Button(action: onOpenFitLab) {
                        banner {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("핏 리포트를 완료하지 못했어요")
                                    .font(CoorditTypography.gmarketBold(size: 12))
                                Text(message)
                                    .font(CoorditTypography.gmarketMedium(size: 9))
                                    .lineLimit(1)
                                    .opacity(0.76)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .coorditPressFeedback()
                    .accessibilityIdentifier("global-fit-analysis-failed")
                }
            }
        }
        .padding(.horizontal, CoorditDesignTokens.GlobalNoticeMetrics.horizontalInset)
        .safeAreaPadding(.top, CoorditDesignTokens.GlobalNoticeMetrics.topInset)
        .offset(y: dismissOffset)
        .opacity(dismissOpacity)
        .contentShape(Rectangle())
        .simultaneousGesture(dismissGesture)
        .transition(
            accessibilityReduceMotion
                ? .opacity
                : .move(edge: .top).combined(with: .opacity)
        )
        .animation(
            accessibilityReduceMotion ? nil : .easeOut(duration: 0.18),
            value: coordinator.isAnalysisNoticeVisible
        )
        .accessibilityHint("위로 쓸어 올리면 알림을 닫을 수 있어요.")
        .accessibilityAction(named: "알림 닫기") {
            dismissNotice()
        }
    }

    private var dismissOpacity: Double {
        max(0.5, 1 + Double(dismissOffset / 120))
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dismissOffset) { value, offset, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                offset = min(0, value.translation.height)
            }
            .onEnded { value in
                let projectedY = min(value.translation.height, value.predictedEndTranslation.height)
                guard abs(projectedY) > abs(value.predictedEndTranslation.width),
                      projectedY <= -32
                else { return }
                dismissNotice()
            }
    }

    private func dismissNotice() {
        withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)) {
            coordinator.dismissAnalysisNotice()
        }
    }

    private func banner<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: CoorditDesignTokens.GlobalNoticeMetrics.contentSpacing, content: content)
            .foregroundStyle(.white)
            .padding(.horizontal, CoorditDesignTokens.GlobalNoticeMetrics.contentInset)
            .frame(maxWidth: .infinity, minHeight: CoorditDesignTokens.GlobalNoticeMetrics.minHeight)
            .background(CoorditDesignTokens.ColorToken.ink)
            .clipShape(RoundedRectangle(cornerRadius: CoorditDesignTokens.GlobalNoticeMetrics.radius, style: .continuous))
            .shadow(
                color: .black.opacity(0.18),
                radius: CoorditDesignTokens.GlobalNoticeMetrics.shadowRadius,
                y: CoorditDesignTokens.GlobalNoticeMetrics.shadowYOffset
            )
    }
}
#endif
