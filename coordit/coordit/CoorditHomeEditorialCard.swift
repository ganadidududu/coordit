import Combine
import SwiftUI

#if os(iOS)
struct CoorditBannerCard: View {
    let metrics: CoorditResponsiveMetrics
    let onStartAnalysis: () -> Void
    @State private var selectedIssue = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private let timer = Timer.publish(every: 7, on: .main, in: .common).autoconnect()

    private let issues: [(label: String, title: String, body: String)] = [
        ("FIT GUIDE", "새 옷,\n잘 맞을까?", "평소 잘 맞는 옷과 비교해\n사이즈 선택을 가볍게."),
        ("MY REFERENCE", "잘 맞는 옷이\n기준이 되니까", "내 옷장에서 기준을 고르고\n실측 차이를 확인해요."),
        ("LAYERING", "겹쳐 입어도,\n나답게", "어깨부터 소매까지,\n옷의 여유를 살펴보세요.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(12)) {
            if typeSize.isAccessibilitySize {
                editorialPage(selectedIssue)
            } else {
                TabView(selection: $selectedIssue) {
                    ForEach(issues.indices, id: \.self) { index in
                        editorialPage(index).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: metrics.value(180))
                .accessibilityIdentifier("coordit-main04-fashion-magazine-carousel")
            }

            let footer = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: metrics.value(8)))
                : AnyLayout(HStackLayout(spacing: metrics.value(12)))
            footer {
                Button("새로운 옷 찾기", action: onStartAnalysis)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(12), relativeTo: .headline))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, metrics.value(16))
                    .padding(.vertical, metrics.value(10))
                    .frame(minHeight: metrics.value(44))
                    .background(CoorditDesignTokens.ColorToken.ink, in: Capsule())
                    .coorditPressFeedback()
                    .accessibilityIdentifier("coordit-main04-new-fit-button")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack(spacing: metrics.value(5)) {
                    ForEach(issues.indices, id: \.self) { index in
                        Button {
                            selectedIssue = index
                        } label: {
                            Capsule()
                                .fill(CoorditDesignTokens.ColorToken.ink.opacity(index == selectedIssue ? 1 : 0.22))
                                .frame(width: metrics.value(index == selectedIssue ? 16 : 5), height: metrics.value(5))
                                .frame(minWidth: metrics.value(44), minHeight: metrics.value(44))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("매거진 \(index + 1)페이지")
                        .accessibilityAddTraits(index == selectedIssue ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, metrics.value(16))
            .padding(.bottom, metrics.value(14))
        }
        .padding(.top, metrics.value(14))
        .background(alignment: .trailing) {
            if !typeSize.isAccessibilitySize {
                Image("CoorditHomeEditorial")
                    .resizable().scaledToFit()
                    .frame(width: metrics.value(205), height: metrics.value(248))
                    .offset(x: metrics.value(9))
                    .accessibilityHidden(true)
            }
        }
        .homePanel(metrics: metrics)
        .accessibilityIdentifier("coordit-main04-banner")
        .onReceive(timer) { _ in
            guard !reduceMotion, !voiceOver, !typeSize.isAccessibilitySize,
                  !ProcessInfo.processInfo.arguments.contains("--coordit-ui-testing") else { return }
            selectedIssue = (selectedIssue + 1) % issues.count
        }
    }

    private func editorialPage(_ index: Int) -> some View {
        let issue = issues[index]
        return ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: metrics.value(12)) {
                Text(issue.label)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(9), relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, metrics.value(10))
                    .padding(.vertical, metrics.value(7))
                    .background(CoorditDesignTokens.ColorToken.ink, in: Capsule())
                Text(issue.title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(27), relativeTo: .largeTitle))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(issue.body)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .body))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("COORDIT MAGAZINE")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(7), relativeTo: .caption2))
                    .tracking(metrics.value(0.8))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
                if typeSize.isAccessibilitySize {
                    Image("CoorditHomeEditorial").resizable().scaledToFit()
                        .frame(height: metrics.value(140)).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : metrics.value(178), alignment: .leading)
            .padding(.horizontal, metrics.value(18))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
    }
}

extension View {
    func homePanel(metrics: CoorditResponsiveMetrics) -> some View {
        self
            .frame(width: metrics.value(366))
            .background(CoorditDesignTokens.ColorToken.panel)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(12)))
            .overlay(RoundedRectangle(cornerRadius: metrics.value(12))
                .stroke(CoorditDesignTokens.ColorToken.line.opacity(0.65), lineWidth: 0.7))
            .shadow(color: CoorditDesignTokens.ColorToken.ink.opacity(0.035), radius: metrics.value(12), y: metrics.value(4))
            .accessibilityElement(children: .contain)
    }
}
#endif
