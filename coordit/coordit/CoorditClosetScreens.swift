import SwiftUI

#if os(iOS)
import PhotosUI
import UIKit

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
    var name: String
    let category: CoorditClosetCategory
    let exactCategory: CoorditFitLabCategory
    var score: Int
    let scoreColor: Color
    let route: CoorditFrameRoute
    var imageData: Data?
    var fitDiffs: CoorditMeasurementMap? = nil
    var backendClothingItemId: String? = nil
    var backendReferenceClothingId: String? = nil

    init(
        id: String,
        name: String,
        category: CoorditClosetCategory,
        exactCategory: CoorditFitLabCategory? = nil,
        score: Int,
        scoreColor: Color,
        route: CoorditFrameRoute,
        imageData: Data?,
        fitDiffs: CoorditMeasurementMap? = nil,
        backendClothingItemId: String? = nil,
        backendReferenceClothingId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.exactCategory = exactCategory ?? (category == .top ? .shirt : .pants)
        self.score = score
        self.scoreColor = scoreColor
        self.route = route
        self.imageData = imageData
        self.fitDiffs = fitDiffs
        self.backendClothingItemId = backendClothingItemId
        self.backendReferenceClothingId = backendReferenceClothingId
    }

    static let seedItems = [
        CoorditClosetItem(id: "oxford", name: "Oxford Shirt", category: .top, exactCategory: .shirt, score: 94, scoreColor: CoorditClosetColors.blue, route: .closetDetailTop, imageData: nil),
        CoorditClosetItem(id: "knit", name: "Relaxed Knit", category: .top, exactCategory: .knit, score: 88, scoreColor: CoorditClosetColors.cyan, route: .closetDetailTop, imageData: nil),
        CoorditClosetItem(id: "denim", name: "Wide Denim", category: .bottom, exactCategory: .jeans, score: 91, scoreColor: CoorditClosetColors.blue, route: .closetDetailBottom, imageData: nil),
        CoorditClosetItem(id: "slacks", name: "Black Slacks", category: .bottom, exactCategory: .pants, score: 0, scoreColor: CoorditClosetColors.navy, route: .closetDetailBottom, imageData: nil),
    ]
}

struct CoorditClosetFamilyView: View {
    let route: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    @Binding var items: [CoorditClosetItem]
    @Binding var selectedItemID: String?
    @Binding var draft: CoorditClosetDraft

    @EnvironmentObject var backendSession: CoorditBackendSessionStore
    @State var selectedCategory: CoorditClosetCategory = .top
    @State private var searchText = ""
    @State private var selectedExactCategory: CoorditFitLabCategory?
    @State var detailVariant: CoorditClosetCategory
    @State var detailPhotoSelection: PhotosPickerItem?
    @State var detailPhotoGenerations: [String: Int]
    @State var reassessingItemID: String?
    @State var reassessmentMessage: String?
    @State var isRenamingDetailItem: Bool
    @State var pendingDetailName: String

    #if DEBUG
    @State var detailPhotoTestStates: [String: String]
    @State var detailPhotoTestRejections: [String: String]
    @State var detailPhotoScenarioAppearances: [String: Int]
    #endif

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
        _detailPhotoSelection = State(initialValue: nil)
        _detailPhotoGenerations = State(initialValue: [:])
        _reassessingItemID = State(initialValue: nil)
        _reassessmentMessage = State(initialValue: nil)
        _isRenamingDetailItem = State(initialValue: false)
        _pendingDetailName = State(initialValue: "")
        #if DEBUG
        _detailPhotoTestStates = State(initialValue: [:])
        _detailPhotoTestRejections = State(initialValue: [:])
        _detailPhotoScenarioAppearances = State(initialValue: [:])
        #endif
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
                        selectedExactCategory = nil
                    }
                    exactCategoryFilter(metrics: metrics)
                    metricsGrid(metrics: metrics, values: overviewMetrics)
                }
                .padding(metrics.value(14))
                .background(CoorditClosetColors.card)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))

                CoorditSolidPrimaryButton(title: "보유 의류 추가하기", metrics: metrics) {
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
        items.filter { item in
            item.category == selectedCategory
                && (selectedExactCategory == nil || item.exactCategory == selectedExactCategory)
                && (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private func exactCategoryFilter(metrics: CoorditResponsiveMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.value(7)) {
                categoryChip(title: "전체", category: nil, metrics: metrics)
                ForEach(CoorditFitLabCategory.allCases.filter {
                    $0.garmentKind == (selectedCategory == .top ? .upper : .lower)
                }) { category in
                    categoryChip(title: category.koreanTitle, category: category, metrics: metrics)
                }
            }
        }
        .accessibilityIdentifier("closet-exact-category-filter")
    }

    private func categoryChip(
        title: String,
        category: CoorditFitLabCategory?,
        metrics: CoorditResponsiveMetrics
    ) -> some View {
        let isSelected = selectedExactCategory == category
        return Button(title) { selectedExactCategory = category }
            .font(CoorditTypography.gmarketMedium(size: metrics.value(10)))
            .foregroundStyle(isSelected ? .white : CoorditClosetColors.navy)
            .padding(.horizontal, metrics.value(10))
            .frame(height: metrics.value(28))
            .background(isSelected ? CoorditClosetColors.navy : CoorditClosetColors.field)
            .clipShape(Capsule())
            .buttonStyle(.plain)
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

    func loadDetailPhoto(_ pickerItem: PhotosPickerItem, for itemID: String) {
        let generation = advanceDetailPhotoGeneration(for: itemID)

        Task {
            let data = try? await pickerItem.loadTransferable(type: Data.self)
            guard detailPhotoGenerations[itemID] == generation else { return }
            detailPhotoSelection = nil
            guard let data, UIImage(data: data) != nil else { return }
            commitDetailPhoto(data, for: itemID)
        }
    }

    func invalidateDetailPhotoLoad(for itemID: String) {
        _ = advanceDetailPhotoGeneration(for: itemID)
        detailPhotoSelection = nil
    }

    private func advanceDetailPhotoGeneration(for itemID: String) -> Int {
        let generation = (detailPhotoGenerations[itemID] ?? 0) + 1
        detailPhotoGenerations[itemID] = generation
        return generation
    }

    private func commitDetailPhoto(_ data: Data, for itemID: String) {
        if let itemIndex = items.firstIndex(where: { $0.id == itemID }) {
            items[itemIndex].imageData = data
        } else if itemID == "closet-draft-preview" {
            draft.garmentImageData = data
        }
    }

    func beginDetailRename(_ item: CoorditClosetItem) {
        pendingDetailName = item.name
        isRenamingDetailItem = true
    }

    func commitDetailName(for itemID: String) {
        let name = pendingDetailName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let itemIndex = items.firstIndex(where: { $0.id == itemID }) {
            items[itemIndex].name = name
        } else if itemID == "closet-draft-preview" {
            draft.name = name
        }
    }

    #if DEBUG
    var detailPhotoTestScenario: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--coordit-ui-testing") else { return nil }
        guard
            let markerIndex = arguments.firstIndex(of: "--coordit-test-detail-photo-scenario"),
            arguments.indices.contains(arguments.index(after: markerIndex))
        else {
            return nil
        }
        return arguments[arguments.index(after: markerIndex)]
    }

    func runDetailPhotoTestScenario(for itemID: String) {
        guard let scenario = detailPhotoTestScenario else { return }
        let appearance = (detailPhotoScenarioAppearances[itemID] ?? 0) + 1
        detailPhotoScenarioAppearances[itemID] = appearance

        switch scenario {
        case "displayed-item-persistence":
            guard appearance == 1 else { return }
            startDetailPhotoTestLoad(
                data: detailPhotoTestImageData(color: .systemBlue),
                token: "valid-b",
                for: itemID,
                delayNanoseconds: 50_000_000
            )
        case "corrupt-and-stale":
            if appearance == 1 {
                applyDetailPhotoTestPayload(
                    detailPhotoTestImageData(color: .systemRed),
                    token: "valid-a",
                    for: itemID,
                    generation: advanceDetailPhotoGeneration(for: itemID)
                )
                startDelayedStaleDetailPhotoTestLoad(
                    data: detailPhotoTestImageData(color: .systemRed),
                    token: "stale-a",
                    for: itemID,
                    afterCommittedToken: "valid-b"
                )
                detailPhotoTestStates[itemID] = "\(itemID)-valid-a-delayed-pending"
            } else if appearance == 2 {
                applyDetailPhotoTestPayload(
                    Data("not-an-image".utf8),
                    token: "corrupt",
                    for: itemID,
                    generation: advanceDetailPhotoGeneration(for: itemID)
                )
                startDetailPhotoTestLoad(
                    data: detailPhotoTestImageData(color: .systemBlue),
                    token: "valid-b",
                    for: itemID,
                    delayNanoseconds: 50_000_000
                )
            }
        case "draft-preview-fallback":
            guard appearance == 1 else { return }
            startDetailPhotoTestLoad(
                data: detailPhotoTestImageData(color: .systemBlue),
                token: "valid-b",
                for: itemID,
                delayNanoseconds: 50_000_000
            )
        case "real-link-add-result-item":
            guard appearance == 1,
                  itemID != "closet-draft-preview",
                  items.contains(where: { $0.id == itemID }) else { return }
            startDetailPhotoTestLoad(
                data: detailPhotoTestImageData(color: .systemBlue),
                token: "real-link-valid-b",
                for: itemID,
                delayNanoseconds: 50_000_000
            )
        default:
            break
        }
    }

    private func startDetailPhotoTestLoad(
        data: Data,
        token: String,
        for itemID: String,
        delayNanoseconds: UInt64
    ) {
        let generation = advanceDetailPhotoGeneration(for: itemID)
        Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            applyDetailPhotoTestPayload(data, token: token, for: itemID, generation: generation)
        }
    }

    private func startDelayedStaleDetailPhotoTestLoad(
        data: Data,
        token: String,
        for itemID: String,
        afterCommittedToken: String
    ) {
        let generation = advanceDetailPhotoGeneration(for: itemID)
        let committedState = "\(itemID)-\(afterCommittedToken)"

        Task {
            for _ in 0..<600 {
                if detailPhotoTestStates[itemID] == committedState {
                    applyDetailPhotoTestPayload(data, token: token, for: itemID, generation: generation)
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            applyDetailPhotoTestPayload(data, token: token, for: itemID, generation: generation)
        }
    }

    private func applyDetailPhotoTestPayload(
        _ data: Data,
        token: String,
        for itemID: String,
        generation: Int
    ) {
        guard detailPhotoGenerations[itemID] == generation else {
            detailPhotoTestRejections[itemID] = "\(itemID)-\(token)-rejected"
            return
        }
        guard UIImage(data: data) != nil else { return }
        commitDetailPhoto(data, for: itemID)
        detailPhotoTestStates[itemID] = "\(itemID)-\(token)"
    }

    private func detailPhotoTestImageData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 12, height: 12)))
        }
    }
    #endif

}
#endif
