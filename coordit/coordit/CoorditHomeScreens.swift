import SwiftUI

#if os(iOS)
struct CoorditMain04Screen: View {
    let onRouteChange: (CoorditFrameRoute) -> Void
    @Binding var closetItems: [CoorditClosetItem]
    @Binding var selectedReferenceIDs: Set<String>
    let fitLabHistory: [CoorditFitLabHistorySnapshot]
    let onOpenFitLabHistory: (CoorditFitLabHistorySnapshot) -> Void
    let onReferenceCommit: (Set<String>) -> Void
    @State private var showsReferenceSelection = false
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore

    init(
        closetItems: Binding<[CoorditClosetItem]>,
        selectedReferenceIDs: Binding<Set<String>>,
        fitLabHistory: [CoorditFitLabHistorySnapshot] = [],
        onOpenFitLabHistory: @escaping (CoorditFitLabHistorySnapshot) -> Void = { _ in },
        onReferenceCommit: @escaping (Set<String>) -> Void,
        onRouteChange: @escaping (CoorditFrameRoute) -> Void = { _ in }
    ) {
        _closetItems = closetItems
        _selectedReferenceIDs = selectedReferenceIDs
        self.fitLabHistory = fitLabHistory
        self.onOpenFitLabHistory = onOpenFitLabHistory
        self.onReferenceCommit = onReferenceCommit
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        CoorditScreenScaffold(route: .main04, onRouteChange: onRouteChange, contentTop: 117, contentBottom: 0) { metrics in
            ScrollView {
            VStack(spacing: metrics.value(12)) {
                CoorditBannerCard(metrics: metrics) { onRouteChange(.fitLabInput) }

                CoorditHomeReferenceCard(
                    items: closetItems,
                    selectedIDs: selectedReferenceIDs,
                    metrics: metrics,
                    onSelect: { showsReferenceSelection = true }
                )

                CoorditFitLabHistoryCard(
                    history: fitLabHistory,
                    metrics: metrics,
                    onOpenHistory: onOpenFitLabHistory
                )

                if backendSession.isWarning {
                    Text("일부 기록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9.5)))
                        .foregroundStyle(CoorditDesignTokens.ColorToken.danger)
                        .frame(width: metrics.value(361), alignment: .leading)
                        .accessibilityIdentifier("home-reference-sync-status")
                }

                CoorditClosetEntryCard(metrics: metrics) {
                    onRouteChange(.closetOverview)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, metrics.value(110))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("coordit-screen-main04")
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showsReferenceSelection) {
            CoorditHomeReferenceSelectionSheet(
                items: closetItems,
                initialSelection: selectedReferenceIDs,
                onCommit: { selection in
                    onReferenceCommit(selection)
                },
                onAddGarment: { onRouteChange(.closetAddMethod) }
            )
        }
    }
}

private struct CoorditHomeFitLabHistoryItem: Identifiable {
    let snapshot: CoorditFitLabHistorySnapshot
    let id: String
    let name: String
    let category: String
    let sizeSummary: String
    let score: String
    let tint: Color

    init(snapshot: CoorditFitLabHistorySnapshot) {
        self.snapshot = snapshot
        self.id = snapshot.analysisID
        self.name = snapshot.product.name
        self.category = snapshot.garmentKind == .upper ? "TOP" : "BOTTOM"
        self.sizeSummary = "\(snapshot.recommendation.recommendedSize) 추천"
        self.score = CoorditFitLabResultMeasurement.score(snapshot.recommendation.fitScore)
        self.tint = snapshot.garmentKind == .upper
            ? Main01DesignTokens.Colors.rgb(54, 93, 168)
            : Main01DesignTokens.Colors.rgb(24, 132, 120)
    }
}

private struct CoorditFitLabHistoryCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let history: [CoorditFitLabHistorySnapshot]
    let metrics: CoorditResponsiveMetrics
    let onOpenHistory: (CoorditFitLabHistorySnapshot) -> Void

    private var recentItems: [CoorditHomeFitLabHistoryItem] {
        history
            .sorted {
                if $0.savedAt == $1.savedAt { return $0.analysisID > $1.analysisID }
                return $0.savedAt > $1.savedAt
            }
            .prefix(2)
            .map { CoorditHomeFitLabHistoryItem(snapshot: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let heading = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: metrics.value(6)))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            heading {
                Text("최근 핏 분석")
                    .font(CoorditTypography.gmarketBold(size: metrics.value(17), relativeTo: .headline))
                    .foregroundStyle(CoorditHomePalette.ink)
                Spacer(minLength: 0)
                Text("최근 저장 \(recentItems.count)개")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(9), relativeTo: .caption))
                    .foregroundStyle(CoorditDesignTokens.ColorToken.muted)
            }
            .padding(.horizontal, metrics.value(16))
            .padding(.top, metrics.value(14))

            Group {
                if recentItems.isEmpty {
                    Text("저장한 핏 리포트가 아직 없어요")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(10), relativeTo: .caption))
                        .foregroundStyle(.black.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: metrics.value(54))
                        .background(Color.black.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                        .accessibilityIdentifier("coordit-main04-history-empty")
                } else {
                    let rows = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: metrics.value(8)))
                        : AnyLayout(HStackLayout(spacing: metrics.value(8)))
                    rows {
                        ForEach(recentItems) { item in
                            Button {
                                onOpenHistory(item.snapshot)
                            } label: {
                                CoorditFitLabHistoryPreviewCard(item: item, metrics: metrics)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityIdentifier("coordit-main04-history-card-\(item.id)")
                                    .accessibilityLabel("\(item.name), \(item.sizeSummary), \(item.score)점, 핏랩 히스토리")
                            }
                            .coorditPressFeedback()
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier("coordit-main04-history-card-\(item.id)")
                            .accessibilityLabel("\(item.name), \(item.sizeSummary), \(item.score)점, 핏랩 히스토리")
                        }
                    }
                }
            }
            .padding(.top, metrics.value(6))
            .padding(.horizontal, metrics.value(16))

        }
        .padding(.bottom, metrics.value(14))
        .homePanel(metrics: metrics)
        .accessibilityIdentifier("coordit-main04-fitlab-card")
    }
}

private struct CoorditFitLabHistoryPreviewCard: View {
    let item: CoorditHomeFitLabHistoryItem
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        HStack(alignment: .center, spacing: metrics.value(7)) {
            VStack(alignment: .leading, spacing: metrics.value(4)) {
                HStack(alignment: .firstTextBaseline, spacing: metrics.value(5)) {
                    Text(item.name)
                        .font(CoorditTypography.gmarketBold(size: metrics.value(10), relativeTo: .caption))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(item.category)
                        .font(CoorditTypography.mona12(size: metrics.value(7.4), relativeTo: .caption2))
                        .foregroundStyle(item.tint.opacity(0.82))
                        .lineLimit(1)
                }

                HStack(spacing: metrics.value(5)) {
                    Text(item.sizeSummary)
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(8.2), relativeTo: .caption2))
                        .foregroundStyle(.black.opacity(0.56))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: metrics.value(4))

            VStack(alignment: .trailing, spacing: metrics.value(1)) {
                Text("SCORE")
                    .font(CoorditTypography.mona12(size: metrics.value(7.4), relativeTo: .caption2))
                    .foregroundStyle(.black.opacity(0.45))
                    .lineLimit(1)

                Text(item.score)
                    .font(CoorditTypography.mona12(size: metrics.value(19), relativeTo: .headline))
                    .foregroundStyle(CoorditHomePalette.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, metrics.value(10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: metrics.value(54))
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    item.tint.opacity(0.08),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous)
                .stroke(.black.opacity(0.1), lineWidth: metrics.value(0.8))
        )
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
    }
}

private struct CoorditClosetEntryCard: View {
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("MY CLOSET")
                    .font(CoorditTypography.climate2019(size: metrics.value(17.2), relativeTo: .headline))
                    .tracking(-0.86 * metrics.scale)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.value(12))
            .frame(width: metrics.value(366))
            .frame(minHeight: metrics.value(44))
            .background(
                LinearGradient(
                    colors: [
                        CoorditHomePalette.card,
                        Main01DesignTokens.Colors.rgb(235, 238, 247),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(10), style: .continuous))
            .shadow(color: .black.opacity(0.035), radius: metrics.value(9), y: metrics.value(3))
        }
        .coorditPressFeedback()
        .padding(.bottom, metrics.value(7))
        .accessibilityIdentifier("coordit-main04-closet-button")
    }
}

private enum CoorditHomePalette {
    static let card = CoorditDesignTokens.ColorToken.panel
    static let ink = CoorditDesignTokens.ColorToken.ink
}
#endif
