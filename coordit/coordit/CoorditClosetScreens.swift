import SwiftUI

#if os(iOS)
enum CoorditClosetCategory: CaseIterable, Equatable {
    case top
    case bottom

    var title: String {
        switch self {
        case .top: "상의"
        case .bottom: "하의"
        }
    }
}

struct CoorditClosetItem: Identifiable {
    let id: String
    let name: String
    let category: CoorditClosetCategory
    let score: Int
    let scoreColor: Color
    let route: CoorditFrameRoute
    let imageData: Data?

    static let seedItems = [
        CoorditClosetItem(id: "oxford", name: "Oxford Shirt", category: .top, score: 94, scoreColor: CoorditClosetColors.blue, route: .closetDetailTop, imageData: nil),
        CoorditClosetItem(id: "knit", name: "Relaxed Knit", category: .top, score: 88, scoreColor: CoorditClosetColors.cyan, route: .closetDetailTop, imageData: nil),
        CoorditClosetItem(id: "denim", name: "Wide Denim", category: .bottom, score: 91, scoreColor: CoorditClosetColors.blue, route: .closetDetailBottom, imageData: nil),
        CoorditClosetItem(id: "slacks", name: "Black Slacks", category: .bottom, score: 0, scoreColor: CoorditClosetColors.navy, route: .closetDetailBottom, imageData: nil),
    ]
}

struct CoorditClosetFamilyView: View {
    let route: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    @Binding var items: [CoorditClosetItem]
    @Binding var selectedItemID: String?
    @Binding var draft: CoorditClosetDraft

    @State var selectedCategory: CoorditClosetCategory = .top
    @State private var searchText = ""
    @State var detailVariant: CoorditClosetCategory

    init(
        route: CoorditFrameRoute,
        items: Binding<[CoorditClosetItem]>,
        selectedItemID: Binding<String?>,
        draft: Binding<CoorditClosetDraft>,
        onRouteChange: @escaping (CoorditFrameRoute) -> Void
    ) {
        self.route = route
        _items = items
        _selectedItemID = selectedItemID
        _draft = draft
        self.onRouteChange = onRouteChange
        _detailVariant = State(initialValue: route == .closetDetailBottom ? .bottom : .top)
    }

    var body: some View {
        CoorditScreenScaffold(route: route, onRouteChange: onRouteChange, contentTop: 115) { metrics in
            switch route {
            case .closetDetailTop:
                detailScreen(
                    metrics: metrics,
                    variant: detailVariant,
                    item: selectedItem(for: .top),
                    screenIdentifier: route.rawValue
                )
                    .onAppear { detailVariant = .top }
            case .closetDetailBottom:
                detailScreen(
                    metrics: metrics,
                    variant: detailVariant,
                    item: selectedItem(for: .bottom),
                    screenIdentifier: route.rawValue
                )
                    .onAppear { detailVariant = .bottom }
            case .closetAddMethod:
                addMethodScreen(metrics: metrics)
            case .closetAddLink:
                addLinkScreen(metrics: metrics)
            case .closetAddPhoto:
                addPhotoScreen(metrics: metrics)
            case .closetAddManual:
                addManualScreen(metrics: metrics)
            case .closetAddLoading:
                addLoadingScreen(metrics: metrics)
            case .closetAddResult:
                detailScreen(
                    metrics: metrics,
                    variant: selectedItem?.category ?? draft.category,
                    item: selectedItem ?? draft.previewItem,
                    screenIdentifier: route.rawValue
                )
            default:
                overviewScreen(metrics: metrics)
            }
        }
    }

    private func overviewScreen(metrics: CoorditResponsiveMetrics) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(22)) {
                CoorditClosetTitleBar(title: "CLOSET", metrics: metrics) {
                    onRouteChange(.main04)
                }

                VStack(alignment: .leading, spacing: metrics.value(12)) {
                    VStack(alignment: .leading, spacing: metrics.value(4)) {
                        Text("현재 베스트 스코어 기준")
                            .font(CoorditTypography.mona12(size: metrics.value(11)))
                            .foregroundStyle(CoorditClosetColors.navy.opacity(0.48))
                        Text("100점 핏 사이즈")
                            .font(CoorditTypography.climate2010(size: metrics.value(21)))
                            .foregroundStyle(CoorditClosetColors.navy)
                            .tracking(metrics.value(-0.9))
                    }
                    CoorditClosetSegment(selected: selectedCategory, metrics: metrics) {
                        selectedCategory = $0
                    }
                    metricsGrid(metrics: metrics, values: overviewMetrics)
                }
                .padding(metrics.value(14))
                .background(CoorditClosetColors.card)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))

                CoorditClosetPrimaryButton(title: "새로운 의류 추가하기", metrics: metrics, height: 39) {
                    draft = CoorditClosetDraft()
                    onRouteChange(.closetAddMethod)
                }
                    .accessibilityIdentifier("closet-add-garment")

                searchField(metrics: metrics)
                garmentGrid(metrics: metrics)
            }
            .padding(.horizontal, metrics.value(16))
            .padding(.bottom, metrics.value(22))
        }
        .accessibilityIdentifier("coordit-screen-closet-overview")
    }

    private var overviewMetrics: [(String, String, Color)] {
        switch selectedCategory {
        case .top:
            [
                ("45.0 cm", "어깨", CoorditClosetColors.navy),
                ("104.0 cm", "가슴", CoorditClosetColors.navy),
                ("70.5 cm", "총장", CoorditClosetColors.navy),
                ("61.0 cm", "소매", CoorditClosetColors.navy),
            ]
        case .bottom:
            [
                ("76.0 cm", "허리", CoorditClosetColors.navy),
                ("101.5 cm", "엉덩이", CoorditClosetColors.navy),
                ("54.0 cm", "허벅지", CoorditClosetColors.navy),
                ("102.0 cm", "총장", CoorditClosetColors.navy),
            ]
        }
    }

    private var filteredItems: [CoorditClosetItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func metricsGrid(metrics: CoorditResponsiveMetrics, values: [(String, String, Color)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: metrics.value(8)), GridItem(.flexible())], spacing: metrics.value(8)) {
            ForEach(values.indices, id: \.self) { index in
                CoorditClosetMetricTile(value: values[index].0, label: values[index].1, color: values[index].2, metrics: metrics)
            }
        }
    }

    private func garmentGrid(metrics: CoorditResponsiveMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: metrics.value(10)), GridItem(.flexible())], spacing: metrics.value(8)) {
            ForEach(filteredItems) { item in
                CoorditClosetGarmentCard(item: item, metrics: metrics) {
                    selectedItemID = item.id
                    onRouteChange(item.route)
                }
            }
        }
    }

    private func searchField(metrics: CoorditResponsiveMetrics) -> some View {
        HStack(spacing: metrics.value(10)) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: metrics.value(22), weight: .semibold))
                .foregroundStyle(.black)
            TextField("보유 의류를 검색해보세요.", text: $searchText)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12)))
                .foregroundStyle(CoorditClosetColors.navy)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, metrics.value(14))
        .frame(height: metrics.value(36))
        .background(CoorditClosetColors.card)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: metrics.value(8), y: metrics.value(3))
        .accessibilityIdentifier("closet-search-field")
    }

    var selectedItem: CoorditClosetItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    private func selectedItem(for category: CoorditClosetCategory) -> CoorditClosetItem {
        if let selectedItem, selectedItem.category == category {
            return selectedItem
        }
        return items.first { $0.category == category } ?? CoorditClosetItem.seedItems[0]
    }

}
#endif
