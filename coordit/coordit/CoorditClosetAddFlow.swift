import PhotosUI
import SwiftUI

#if os(iOS)
enum CoorditClosetAddMethod: String, CaseIterable, Identifiable {
    case link
    case photo
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .link: "링크로 불러오기"
        case .photo: "사진으로 첨부하기"
        case .manual: "직접 입력하기"
        }
    }

    var description: String {
        switch self {
        case .link: "상품 링크에서 사이즈 정보를 불러와요."
        case .photo: "사이즈표 사진을 분석해요."
        case .manual: "실측 사이즈를 직접 입력해요."
        }
    }

    var symbolName: String {
        switch self {
        case .link: "link"
        case .photo: "photo.on.rectangle.angled"
        case .manual: "ruler"
        }
    }

    var route: CoorditFrameRoute {
        switch self {
        case .link: .closetAddLink
        case .photo: .closetAddPhoto
        case .manual: .closetAddManual
        }
    }
}

struct CoorditClosetDraft {
    var method: CoorditClosetAddMethod?
    var name = ""
    var category: CoorditClosetCategory = .top
    var productLink = ""
    var garmentImageData: Data?
    var sizeChartImageData: Data?
    var measurement1 = ""
    var measurement2 = ""
    var measurement3 = ""
    var measurement4 = ""

    var score: Int {
        switch method {
        case .link: 93
        case .photo: 91
        case .manual: 96
        case nil: 92
        }
    }

    var previewItem: CoorditClosetItem {
        CoorditClosetItem(
            id: "closet-draft-preview",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "새로운 의류" : name,
            category: category,
            score: score,
            scoreColor: CoorditClosetColors.blue,
            route: .closetAddResult,
            imageData: garmentImageData
        )
    }
}

extension CoorditClosetFamilyView {
    func addMethodScreen(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditClosetAddMethodScreen(metrics: metrics) {
            onRouteChange(.closetOverview)
        } onSelect: { method in
            draft.method = method
            onRouteChange(method.route)
        }
    }

    func addLinkScreen(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditClosetLinkInputScreen(draft: $draft, metrics: metrics) {
            onRouteChange(.closetAddMethod)
        } onSubmit: {
            submitDraft()
        }
    }

    func addPhotoScreen(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditClosetPhotoInputScreen(draft: $draft, metrics: metrics) {
            onRouteChange(.closetAddMethod)
        } onSubmit: {
            submitDraft()
        }
    }

    func addManualScreen(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditClosetManualInputScreen(draft: $draft, metrics: metrics) {
            onRouteChange(.closetAddMethod)
        } onSubmit: {
            submitDraft()
        }
    }

    func addLoadingScreen(metrics: CoorditResponsiveMetrics) -> some View {
        CoorditClosetAddLoadingScreen(metrics: metrics) {
            onRouteChange(.closetOverview)
        } onComplete: {
            onRouteChange(.closetAddResult)
        }
    }

    private func submitDraft() {
        let submittedDraft = draft
        let trimmedName = submittedDraft.trimmedName
        guard !trimmedName.isEmpty else { return }

        let item = CoorditClosetItem(
            id: UUID().uuidString,
            name: trimmedName,
            category: submittedDraft.category,
            score: submittedDraft.score,
            scoreColor: CoorditClosetColors.blue,
            route: .closetAddResult,
            imageData: submittedDraft.garmentImageData
        )

        items.insert(item, at: 0)
        selectedItemID = item.id
        selectedCategory = item.category
        onRouteChange(.closetAddLoading)

        Task { @MainActor in
            guard let saved = await backendSession.saveReferenceClothing(from: submittedDraft) else { return }
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[index].backendClothingItemId = saved.clothingItemId
            items[index].backendReferenceClothingId = saved.referenceClothingId
        }
    }
}

private struct CoorditClosetAddMethodScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onSelect: (CoorditClosetAddMethod) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(18)) {
                CoorditClosetTitleBar(title: "ADD CLOTHES", metrics: metrics, horizontalOutset: 7, onBack: onBack)

                VStack(alignment: .leading, spacing: metrics.value(5)) {
                    Text("어떻게 추가할까요?")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(20)))
                        .foregroundStyle(CoorditClosetColors.navy)
                    Text("가지고 있는 정보에 맞는 방식을 선택해주세요.")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(11)))
                        .foregroundStyle(CoorditClosetColors.navy.opacity(0.46))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, metrics.value(5))

                VStack(spacing: metrics.value(11)) {
                    ForEach(CoorditClosetAddMethod.allCases) { method in
                        Button {
                            onSelect(method)
                        } label: {
                            HStack(spacing: metrics.value(14)) {
                                Image(systemName: method.symbolName)
                                    .font(.system(size: metrics.value(23), weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: metrics.value(50), height: metrics.value(50))
                                    .background(CoorditClosetColors.navy)
                                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(9)))

                                VStack(alignment: .leading, spacing: metrics.value(5)) {
                                    Text(method.title)
                                        .font(CoorditTypography.gmarketBold(size: metrics.value(15)))
                                        .foregroundStyle(.black)
                                    Text(method.description)
                                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9)))
                                        .foregroundStyle(CoorditClosetColors.navy.opacity(0.48))
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: metrics.value(16), weight: .bold))
                                    .foregroundStyle(CoorditClosetColors.navy.opacity(0.34))
                            }
                            .padding(metrics.value(13))
                            .frame(maxWidth: .infinity, minHeight: metrics.value(84))
                            .background(CoorditClosetColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: metrics.value(9)))
                            .overlay(
                                RoundedRectangle(cornerRadius: metrics.value(9))
                                    .stroke(CoorditClosetColors.navy.opacity(0.08), lineWidth: metrics.value(0.8))
                            )
                            .shadow(color: .black.opacity(0.06), radius: metrics.value(8), y: metrics.value(3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("closet-add-method-\(method.rawValue)")
                    }
                }
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(28))
        }
        .accessibilityIdentifier("coordit-screen-closet-add-method")
    }
}

private struct CoorditClosetLinkInputScreen: View {
    @Binding var draft: CoorditClosetDraft
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onSubmit: () -> Void

    @FocusState private var isLinkFocused: Bool

    private var isReady: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.productLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(16)) {
                CoorditClosetTitleBar(title: "LINK INPUT", metrics: metrics, horizontalOutset: 7, onBack: onBack)
                CoorditClosetBasicsCard(draft: $draft, metrics: metrics)

                CoorditClosetFormCard(title: "상품 링크", subtitle: "사이즈 정보가 있는 상품 페이지 주소를 붙여넣어 주세요.", metrics: metrics) {
                    HStack(spacing: metrics.value(10)) {
                        Image(systemName: "link")
                            .foregroundStyle(CoorditClosetColors.navy.opacity(0.56))
                        TextField("https://", text: $draft.productLink)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(12)))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isLinkFocused)
                            .onTapGesture { isLinkFocused = true }
                            .accessibilityIdentifier("closet-product-link")
                    }
                    .padding(.horizontal, metrics.value(13))
                    .frame(height: metrics.value(45))
                    .background(CoorditClosetColors.field)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
                }

                CoorditClosetSubmitButton(title: "링크 분석하기", isEnabled: isReady, metrics: metrics, action: onSubmit)
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(28))
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("coordit-screen-closet-add-link")
    }
}

private struct CoorditClosetPhotoInputScreen: View {
    @Binding var draft: CoorditClosetDraft
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onSubmit: () -> Void

    private var isReady: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.sizeChartImageData != nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(16)) {
                CoorditClosetTitleBar(title: "PHOTO INPUT", metrics: metrics, horizontalOutset: 7, onBack: onBack)
                CoorditClosetBasicsCard(draft: $draft, metrics: metrics)

                CoorditClosetFormCard(title: "사진 첨부", subtitle: "사이즈표 전체가 보이게 첨부해주세요.", metrics: metrics) {
                    CoorditClosetPhotoPickerSlot(
                        title: "사이즈표",
                        subtitle: "표 전체가 보이게",
                        imageData: $draft.sizeChartImageData,
                        metrics: metrics,
                        identifier: "closet-size-chart-photo"
                    )
                }

                CoorditClosetSubmitButton(title: "사진 분석하기", isEnabled: isReady, metrics: metrics, action: onSubmit)
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(28))
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("coordit-screen-closet-add-photo")
        .task {
            injectSizeChartFixtureIfRequested()
        }
    }

    private func injectSizeChartFixtureIfRequested() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--coordit-ui-testing"),
              arguments.contains("--coordit-test-valid-size-chart"),
              draft.sizeChartImageData == nil,
              let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="),
              UIImage(data: data) != nil else { return }
        draft.sizeChartImageData = data
#endif
    }
}

private struct CoorditClosetManualInputScreen: View {
    @Binding var draft: CoorditClosetDraft
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onSubmit: () -> Void

    private var measurementFields: [(String, WritableKeyPath<CoorditClosetDraft, String>)] {
        switch draft.category {
        case .top:
            [("어깨", \.measurement1), ("가슴", \.measurement2), ("총장", \.measurement3), ("소매", \.measurement4)]
        case .bottom:
            [("허리", \.measurement1), ("엉덩이", \.measurement2), ("밑위", \.measurement3), ("아웃심", \.measurement4)]
        }
    }

    private var isReady: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        measurementFields.allSatisfy { !draft[keyPath: $0.1].isEmpty }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: metrics.value(16)) {
                CoorditClosetTitleBar(title: "MANUAL INPUT", metrics: metrics, horizontalOutset: 7, onBack: onBack)
                CoorditClosetBasicsCard(draft: $draft, metrics: metrics)

                CoorditClosetFormCard(title: "실측 사이즈", subtitle: "단위는 cm로 입력해주세요.", metrics: metrics) {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: metrics.value(8)), GridItem(.flexible())],
                        spacing: metrics.value(8)
                    ) {
                        ForEach(Array(measurementFields.enumerated()), id: \.offset) { index, field in
                            VStack(alignment: .leading, spacing: metrics.value(5)) {
                                Text(field.0)
                                    .font(CoorditTypography.gmarketMedium(size: metrics.value(9)))
                                    .foregroundStyle(CoorditClosetColors.navy.opacity(0.5))
                                HStack(spacing: metrics.value(4)) {
                                    TextField(
                                        "0.0",
                                        text: Binding(
                                            get: { draft[keyPath: field.1] },
                                            set: { draft[keyPath: field.1] = $0 }
                                        )
                                    )
                                    .font(CoorditTypography.gmarketBold(size: metrics.value(14)))
                                    .keyboardType(.decimalPad)
                                    .accessibilityIdentifier("closet-manual-measurement-\(index)")
                                    Text("cm")
                                        .font(CoorditTypography.gmarketMedium(size: metrics.value(9)))
                                        .foregroundStyle(CoorditClosetColors.navy.opacity(0.36))
                                }
                                .padding(.horizontal, metrics.value(10))
                                .frame(height: metrics.value(42))
                                .background(CoorditClosetColors.field)
                                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
                            }
                        }
                    }
                }

                CoorditClosetSubmitButton(title: "핏 스코어 계산하기", isEnabled: isReady, metrics: metrics, action: onSubmit)
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(28))
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("coordit-screen-closet-add-manual")
    }
}

private struct CoorditClosetAddLoadingScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: metrics.value(18)) {
            CoorditClosetTitleBar(title: "FIT CHECK", metrics: metrics, horizontalOutset: 7, onBack: onBack)

            Spacer(minLength: metrics.value(120))
            ZStack {
                Image(CoorditAssetNames.loadingMannequin)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(58), height: metrics.value(82))
                    .opacity(0.28)
                Image(CoorditAssetNames.loadingOrbit)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(85), height: metrics.value(44))
                    .opacity(0.75)
            }
            Text("새 의류의 핏 스코어 계산 중 . . .")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(15)))
                .foregroundStyle(Color.black.opacity(0.76))
            Text("입력한 정보를 바탕으로 가장 가까운 핏을 찾고 있어요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(9)))
                .foregroundStyle(CoorditClosetColors.navy.opacity(0.42))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.value(22))
        .accessibilityIdentifier("coordit-screen-closet-add-loading")
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

private struct CoorditClosetBasicsCard: View {
    @Binding var draft: CoorditClosetDraft
    let metrics: CoorditResponsiveMetrics

    @FocusState private var isNameFocused: Bool

    var body: some View {
        CoorditClosetFormCard(title: "기본 정보", subtitle: "옷장에 표시할 이름과 종류를 입력해주세요.", metrics: metrics) {
            TextField("의류 이름", text: $draft.name)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12)))
                .focused($isNameFocused)
                .onTapGesture { isNameFocused = true }
                .padding(.horizontal, metrics.value(13))
                .frame(height: metrics.value(45))
                .background(CoorditClosetColors.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
                .accessibilityIdentifier("closet-garment-name")

            CoorditClosetSegment(selected: draft.category, metrics: metrics) {
                draft.category = $0
            }
        }
    }
}

private struct CoorditClosetFormCard<Content: View>: View {
    let title: String
    let subtitle: String
    let metrics: CoorditResponsiveMetrics
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, metrics: CoorditResponsiveMetrics, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(11)) {
            VStack(alignment: .leading, spacing: metrics.value(4)) {
                Text(title)
                    .font(CoorditTypography.gmarketBold(size: metrics.value(15)))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(9)))
                    .foregroundStyle(CoorditClosetColors.navy.opacity(0.44))
            }
            content
        }
        .padding(metrics.value(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditClosetColors.card)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(9)))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(9))
                .stroke(CoorditClosetColors.navy.opacity(0.07), lineWidth: metrics.value(0.8))
        )
    }
}

private struct CoorditClosetPhotoPickerSlot: View {
    let title: String
    let subtitle: String
    @Binding var imageData: Data?
    let metrics: CoorditResponsiveMetrics
    let identifier: String

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.value(8))
                    .fill(CoorditClosetColors.field)

                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
                        .overlay(alignment: .bottom) {
                            Text("변경하기")
                                .font(CoorditTypography.gmarketBold(size: metrics.value(9)))
                                .foregroundStyle(.white)
                                .padding(.horizontal, metrics.value(10))
                                .frame(height: metrics.value(24))
                                .background(CoorditClosetColors.navy.opacity(0.82))
                                .clipShape(Capsule())
                                .padding(.bottom, metrics.value(8))
                        }
                } else {
                    VStack(spacing: metrics.value(7)) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: metrics.value(25), weight: .semibold))
                            .foregroundStyle(CoorditClosetColors.navy)
                        Text(title)
                            .font(CoorditTypography.gmarketBold(size: metrics.value(12)))
                            .foregroundStyle(.black)
                        Text(subtitle)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(8)))
                            .foregroundStyle(CoorditClosetColors.navy.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(metrics.value(8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.value(126))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.value(8))
                    .stroke(style: StrokeStyle(lineWidth: metrics.value(1), dash: [metrics.value(5)]))
                    .foregroundStyle(CoorditClosetColors.navy.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(imageData == nil ? "empty" : "selected")
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await MainActor.run {
                    imageData = data
                }
            }
        }
    }
}

private struct CoorditClosetSubmitButton: View {
    let title: String
    let isEnabled: Bool
    let metrics: CoorditResponsiveMetrics
    let action: () -> Void

    var body: some View {
        CoorditClosetPrimaryButton(title: title, metrics: metrics, height: 44, action: action)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.38)
            .accessibilityIdentifier("closet-add-submit")
    }
}
#endif
