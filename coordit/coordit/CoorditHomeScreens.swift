import SwiftUI

#if os(iOS)
/// 홈 화면: 하나의 긴 세로 스크롤이 4개 화면(카드 뉴스 / FIT LAB / CLOSET / 실타래·푸터)에서 멈춘다.
struct CoorditMain04Screen: View {
    let onRouteChange: (CoorditFrameRoute) -> Void
    @Binding var closetItems: [CoorditClosetItem]
    @Binding var selectedReferenceIDs: Set<String>
    let fitLabHistory: [CoorditFitLabHistorySnapshot]
    let threadBalance: Int
    let onOpenFitLabHistory: (CoorditFitLabHistorySnapshot) -> Void
    let onReferenceCommit: (Set<String>) -> Void

    @State private var showsReferenceSelection = false
    @State private var anchors = CoorditHomeSnapAnchors()
    @State private var currentOffset: CGFloat = 0
    @State private var scrollExtent = CoorditHomeScrollExtent()
    @State private var fitLabHeight: CGFloat = 0
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore

    private static let contentSpace = "coordit-home-content"

    init(
        closetItems: Binding<[CoorditClosetItem]>,
        selectedReferenceIDs: Binding<Set<String>>,
        fitLabHistory: [CoorditFitLabHistorySnapshot] = [],
        threadBalance: Int = 0,
        onOpenFitLabHistory: @escaping (CoorditFitLabHistorySnapshot) -> Void = { _ in },
        onReferenceCommit: @escaping (Set<String>) -> Void,
        onRouteChange: @escaping (CoorditFrameRoute) -> Void = { _ in }
    ) {
        _closetItems = closetItems
        _selectedReferenceIDs = selectedReferenceIDs
        self.fitLabHistory = fitLabHistory
        self.threadBalance = threadBalance
        self.onOpenFitLabHistory = onOpenFitLabHistory
        self.onReferenceCommit = onReferenceCommit
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        CoorditScreenScaffold(route: .main04, onRouteChange: onRouteChange, contentTop: 0, contentBottom: 0) { _ in
            GeometryReader { geometry in
                let layout = CoorditHomeLayout(width: geometry.size.width)

                ZStack {
                    scrollContent(layout: layout)

                    // 상·하단 크롬. FIT LAB 화면에 가까워질수록 위아래가 남색으로 차오른다.
                    let stops = resolvedStops(layout: layout)
                    CoorditHomeChromeOverlay(
                        layout: layout,
                        tint: CoorditHomeChromeTint.resolve(
                            offset: currentOffset,
                            fitLabStop: stops.fitLab,
                            closetStop: stops.closet
                        ),
                        bottomCoverHeight: bottomCoverHeight(fitLabStop: stops.fitLab, viewport: geometry.size.height),
                        fitLabTopOnScreen: anchors.fitLabTop.map { $0 - currentOffset },
                        closetTopOnScreen: anchors.closetTop.map { $0 - currentOffset },
                        threadTopOnScreen: anchors.threadTop.map { $0 - currentOffset },
                        viewportHeight: geometry.size.height
                    )
                }
            }
            .ignoresSafeArea()
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

    /// 실제 정지 지점(스크롤 범위로 보정된 값).
    private func resolvedStops(layout: CoorditHomeLayout) -> (fitLab: CGFloat?, closet: CGFloat?) {
        let maxOffset = scrollExtent.maxOffset
        func clamp(_ value: CGFloat?) -> CGFloat? {
            value.map { min(max(0, $0), maxOffset) }
        }
        let fitLab = anchors.fitLabTop.map { $0 - layout.value(CoorditHomeSnapStop.fitLab.sectionInset) }
        let closet = anchors.closetTop.map { $0 - layout.value(CoorditHomeSnapStop.closet.sectionInset) }
        return (clamp(fitLab), clamp(closet))
    }

    /// 2번 화면에서 FIT LAB 섹션 아래로 드러나는 영역 높이.
    private func bottomCoverHeight(fitLabStop: CGFloat?, viewport: CGFloat) -> CGFloat {
        guard let fitLabStop, let fitLabTop = anchors.fitLabTop else { return 0 }
        let fitLabBottomOnScreen = fitLabTop + fitLabHeight - fitLabStop
        return viewport - fitLabBottomOnScreen + 40
    }

    private func scrollContent(layout: CoorditHomeLayout) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                CoorditHomeCardNewsSection(layout: layout, items: CoorditHomeCardNews.items)

                CoorditHomeFitLabSection(
                    layout: layout,
                    closetItems: closetItems,
                    selectedReferenceIDs: selectedReferenceIDs,
                    history: fitLabHistory,
                    onStartAnalysis: { onRouteChange(.fitLabInput) },
                    onSelectReference: { showsReferenceSelection = true },
                    onOpenHistory: onOpenFitLabHistory
                )
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(Self.contentSpace))
                } action: { frame in
                    anchors.fitLabTop = frame.minY
                    fitLabHeight = frame.height
                }

                CoorditHomeClosetSection(
                    layout: layout,
                    closetItems: closetItems,
                    selectedReferenceIDs: selectedReferenceIDs,
                    onOpenCloset: { onRouteChange(.closetOverview) },
                    onAddGarment: { onRouteChange(.closetOverview) }
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named(Self.contentSpace)).minY
                } action: { anchors.closetTop = $0 }

                if backendSession.isWarning {
                    Text("일부 기록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
                        .font(CoorditTypography.gmarketMedium(size: layout.value(18), relativeTo: .caption))
                        .foregroundStyle(CoorditDesignTokens.ColorToken.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, layout.gutter)
                        .padding(.vertical, layout.value(12))
                        .background(CoorditHomePalette.slate)
                        .accessibilityIdentifier("home-reference-sync-status")
                }

                CoorditHomeThreadSection(
                    layout: layout,
                    threadBalance: threadBalance,
                    onOpenHistory: { onRouteChange(.myPageThreadCharge) },
                    onWatchAd: { onRouteChange(.myPageThreadCharge) }
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named(Self.contentSpace)).minY
                } action: { anchors.threadTop = $0 }

                CoorditHomeFooter(layout: layout, onRouteChange: onRouteChange)
            }
            .coordinateSpace(name: Self.contentSpace)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("coordit-screen-main04")
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(
            CoorditHomeSnapScrollBehavior(
                anchors: anchors.offsets(layout: layout)
            )
        )
        .onScrollGeometryChange(for: CoorditHomeScrollExtent.self) { geometry in
            CoorditHomeScrollExtent(
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                maxOffset: max(0, geometry.contentSize.height - geometry.containerSize.height),
                viewport: geometry.containerSize.height
            )
        } action: { _, extent in
            currentOffset = extent.offset
            scrollExtent = extent
        }
        .ignoresSafeArea()
    }
}
struct CoorditHomeScrollExtent: Equatable {
    var offset: CGFloat = 0
    var maxOffset: CGFloat = 0
    var viewport: CGFloat = 0
}
#endif
