import SwiftUI

#if os(iOS)
struct CoorditGlobalFitAnalysisBanner: View {
    @ObservedObject var coordinator: CoorditFitLabCoordinator
    let onOpenResult: (CoorditFrameRoute) -> Void
    let onOpenFitLab: () -> Void

    var body: some View {
        Group {
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
                .buttonStyle(.plain)
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
                .buttonStyle(.plain)
                .accessibilityIdentifier("global-fit-analysis-failed")
            }
        }
        .padding(.horizontal, CoorditDesignTokens.GlobalNoticeMetrics.horizontalInset)
        .safeAreaPadding(.top, CoorditDesignTokens.GlobalNoticeMetrics.topInset)
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
