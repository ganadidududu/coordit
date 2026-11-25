import SwiftUI
import Darwin

#if os(iOS)
struct CoorditFitLabURLInputView: View {
    @EnvironmentObject private var tutorial: CoorditFitLabTutorial
    let metrics: CoorditResponsiveMetrics
    @Binding var draft: CoorditFitLabDraft
    let requestLedger: () -> [String]
    let prefill: (URL, CoorditFitLabCategory?) async throws -> CoorditFitLabURLPrefillResponse
    let initialURL: URL?
    let onSwitchToOCR: () -> Void
    let onSwitchToManual: () -> Void

    @State private var stage: Stage = .entry
    @State private var urlText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var kind: CoorditFitLabGarmentKind = .upper
    @State private var category: CoorditFitLabCategory = .tshirt
    @State private var usesAutomaticCategory = true
    @State private var productName = ""
    @State private var brand = ""
    @State private var rows: [EditableRow] = []
    @State private var validationMessage: String?
    @State private var importGeneration = 0
    @State private var importRequest: Task<Void, Never>?
    /// 웹뷰로 직접 긁을 때의 진행 상태. nil이면 웹뷰 화면을 띄우지 않는다.
    @State private var webImportURL: URL?
    @FocusState private var focusedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.value(14)) {
                if CoorditTutorialExample.matches(URL(string: urlText)) {
                    CoorditExampleNotice()
                }
                switch stage {
                case .entry:
                    entry
                case .review:
                    review
                case .confirmed:
                    confirmed
                }

                #if DEBUG
                ledgerProbe
                #endif
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(120))
        }
        .coorditScrollEdgeTreatment(topFade: metrics.value(14))
        .id(stage)
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(item: Binding(
            get: { webImportURL.map { WebImportTarget($0) } },
            set: { webImportURL = $0?.url }
        )) { target in
            let url = target.url
            CoorditFitLabWebImportScreen(
                url: url,
                metrics: metrics,
                onExtracted: completeWebImport,
                onFallbackToServer: {
                    webImportURL = nil
                    startServerImport(url: url)
                },
                onCancel: {
                    webImportURL = nil
                }
            )
            .interactiveDismissDisabled()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    if stage == .entry { completeLinkEntry() } else { focusedField = nil }
                }
            }
        }
        .accessibilityIdentifier("fitlab-url-flow")
        .onDisappear {
            invalidateImport()
        }
        .onAppear {
            applyInitialURLIfNeeded()
            updateTutorialForEntry()
        }
        .onChange(of: focusedField) { _, field in
            if stage == .entry, field == "url" { tutorial.show(.link) }
        }
        .onChange(of: stage) { _, stage in
            switch stage {
            case .entry: updateTutorialForEntry()
            case .review: tutorial.show(.review)
            case .confirmed: tutorial.show(.continueToReferences)
            }
        }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: metrics.value(12)) {
            Text("상품 링크를 넣어주세요")
                .font(CoorditTypography.gmarketBold(size: metrics.value(18), relativeTo: .headline))
                .foregroundStyle(Color.black)
            Text("링크의 상품과 사이즈 정보를 무료로 정리해요.")
                .font(CoorditTypography.gmarketLight(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(Color.black.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: metrics.value(12)) {
                CoorditLinkInputRow(text: $urlText, metrics: metrics, pasteIdentifier: "fitlab-url-paste") {
                    TextField("상품 링크 입력", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.URL)
                        .submitLabel(.done)
                        .onSubmit(completeLinkEntry)
                        .focused($focusedField, equals: "url")
                        .onTapGesture { focusedField = "url" }
                        .accessibilityLabel("상품 링크")
                        .accessibilityIdentifier("fitlab-url-field")
                }
                .disabled(isLoading || tutorial.requiresSkipConfirmation)

                if tutorial.step == .link {
                    Button("다음", action: completeLinkEntry)
                        .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary, height: 44))
                        .disabled(isLoading || Self.validatedURL(from: urlText) == nil)
                        .accessibilityIdentifier("fitlab-url-next")
                }
            }
            .fitLabTutorialTarget(.link)

            classificationControls

            if let errorMessage {
                Text(errorMessage)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .footnote))
                    .foregroundStyle(Color.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("fitlab-url-error")
            }

            Button(action: startImport) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isLoading ? "불러오는 중" : "다음")
                }
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, metrics.value(12))
                .background(CoorditFitLabPalette.ink)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
            }
            .coorditPressFeedback()
            .disabled(isLoading)
            .accessibilityIdentifier("fitlab-url-import")
            .fitLabTutorialTarget(.importLink)

            if errorMessage != nil {
                VStack(spacing: metrics.value(8)) {
                    urlFallbackButton(title: "다시 시도", isPrimary: true, action: startImport)

                    HStack(spacing: metrics.value(8)) {
                        urlFallbackButton(title: "사진 OCR로 전환", action: switchToOCR)
                        .accessibilityIdentifier("fitlab-url-switch-to-ocr")
                        urlFallbackButton(title: "수동 입력으로 전환", action: switchToManual)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(metrics.value(15))
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
        )
    }

    private func urlFallbackButton(
        title: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(CoorditTypography.gmarketBold(size: metrics.value(11)))
                .foregroundStyle(isPrimary ? Color.white : CoorditFitLabPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(40))
                .background(isPrimary ? CoorditFitLabPalette.ink : CoorditFitLabPalette.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                        .stroke(CoorditFitLabPalette.ink.opacity(isPrimary ? 0 : 0.14), lineWidth: metrics.value(0.8))
                }
        }
        .coorditPressFeedback()
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: metrics.value(14)) {
            #if DEBUG
            Text("URL 검토")
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityIdentifier("fitlab-url-review")
            #endif
            Text("추출 결과 · 저장 전 확인 필요")
                .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                .foregroundStyle(Color.black)

            classificationControls

            HStack {
                Text("현재 카테고리 \(title(for: category))")
                Spacer(minLength: 0)
                Text("선택한 기준 옷 \(draft.selectedReferenceIDs.count)개")
                    .accessibilityIdentifier("fitlab-url-selected-reference-count")
            }
            .font(CoorditTypography.gmarketLight(size: metrics.value(10), relativeTo: .caption))
            .foregroundStyle(Color.black.opacity(0.62))

            TextField("상품명", text: $productName)
                .padding(metrics.value(10))
                .background(CoorditFitLabPalette.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                .focused($focusedField, equals: "product")
                .accessibilityIdentifier("fitlab-url-product-name")

            TextField("브랜드 (선택)", text: $brand)
                .padding(metrics.value(10))
                .background(CoorditFitLabPalette.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                .focused($focusedField, equals: "brand")
                .accessibilityIdentifier("fitlab-url-brand")

            Text("모든 수치는 평평하게 놓고 잰 단면(cm)이에요.")
                .font(CoorditTypography.gmarketLight(size: metrics.value(11), relativeTo: .footnote))
                .foregroundStyle(Color.black.opacity(0.65))

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                sizeRow(row, index: index)
            }

            Button {
                rows.append(EditableRow())
            } label: {
                Label("사이즈 행 추가", systemImage: "plus.circle.fill")
            }
            .buttonStyle(
                CoorditContentActionButtonStyle(
                    prominence: .secondary,
                    height: metrics.value(48),
                    cornerRadius: metrics.value(7),
                    fontSize: metrics.value(13)
                )
            )
            .accessibilityIdentifier("fitlab-url-add-size-row")

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .accessibilityIdentifier("fitlab-url-validation-error")
            }

            Button { confirm() } label: {
                Text("확인하고 1차 분석 보기")
                    .font(CoorditTypography.gmarketBold(size: metrics.value(14), relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, metrics.value(12))
                    .background(CoorditFitLabPalette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
            }
            .coorditPressFeedback()
            .accessibilityIdentifier("fitlab-url-confirm")
            .fitLabTutorialTarget(.review)

            #if DEBUG
            Text(urlText.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityIdentifier("fitlab-url-field-preserved")

            #endif
        }
        .padding(metrics.value(15))
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
        )
    }

    private var confirmed: some View {
        VStack(alignment: .leading, spacing: metrics.value(12)) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: metrics.value(42)))
                .foregroundStyle(CoorditFitLabPalette.ink)
            Text("링크에서 가져온 사이즈표를 확인했어요")
                .font(CoorditTypography.gmarketBold(size: metrics.value(18), relativeTo: .headline))
                .foregroundStyle(Color.black)
            Text(confirmedSummary)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                .foregroundStyle(Color.black)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fitlab-url-confirmed")
            Text("아직 상품, 사이즈, 추천, 리포트는 저장하거나 요청하지 않았어요.")
                .font(CoorditTypography.gmarketLight(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(Color.black.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Button("가져온 값 다시 편집") { stage = .review }
                .buttonStyle(
                    CoorditContentActionButtonStyle(
                        prominence: .secondary,
                        height: metrics.value(48),
                        cornerRadius: metrics.value(7),
                        fontSize: metrics.value(13)
                    )
                )
            CoorditFitLabPrimaryButton(title: "기준 옷 선택으로", metrics: metrics) {
                tutorial.advance(from: .continueToReferences, to: .references)
                draft.isSourceConfirmed = true
            }
            .accessibilityIdentifier("fitlab-url-continue-to-references")
            .fitLabTutorialTarget(.continueToReferences)
        }
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous))
    }

    private func sizeRow(_ row: EditableRow, index: Int) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(8)) {
            HStack {
                Text("사이즈 \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive) { rows.removeAll { $0.id == row.id } } label: {
                    Image(systemName: "trash")
                }
                .foregroundStyle(Color.black)
                .accessibilityLabel("사이즈 \(index + 1) 행 삭제")
            }

            TextField("사이즈명", text: rowBinding(row.id, keyPath: \.label))
                .padding(metrics.value(9))
                .background(CoorditFitLabPalette.field)
                .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                .focused($focusedField, equals: "url-row-\(row.id.uuidString)-label")
                .accessibilityIdentifier("fitlab-url-size-label-row-\(index)")

            ForEach(measurementKeys) { key in
                HStack {
                    Text(measurementTitle(for: key))
                        .font(CoorditTypography.gmarketLight(size: metrics.value(11), relativeTo: .caption))
                    Spacer(minLength: metrics.value(8))
                    TextField("cm", text: measurementBinding(row.id, key: key))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: metrics.value(92))
                        .frame(minHeight: metrics.value(52))
                        .padding(metrics.value(8))
                        .background(CoorditFitLabPalette.field)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.value(6), style: .continuous))
                        .focused($focusedField, equals: "url-row-\(row.id.uuidString)-\(key.rawValue)")
                        .accessibilityIdentifier("fitlab-url-measurement-\(key.rawValue)-row-\(index)")
                }
            }
        }
        .padding(metrics.value(12))
        .background(CoorditFitLabPalette.empty.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
    }

    #if DEBUG
    private var ledgerProbe: some View {
        Group {
            Text(ledgerSummary)
                .accessibilityIdentifier("fitlab-url-request-ledger")
            Text(requestLedger().joined(separator: "|"))
                .accessibilityIdentifier("fitlab-url-request-ledger-detail")
        }
        .font(.system(size: 1))
        .frame(width: 1, height: 1)
        .opacity(0.01)
    }

    private var ledgerSummary: String {
        let ledger = requestLedger()
        return [
            "prefill=\(ledger.filter { $0.hasPrefix("prefill:") }.count)",
            "references=\(ledger.filter { $0.hasPrefix("references:") }.count)",
            "product=\(ledger.filter { $0 == "create-product" }.count)",
            "size=\(ledger.filter { $0.hasPrefix("create-size:") }.count)",
            "recommend=\(ledger.filter { $0 == "recommend" }.count)",
            "report=\(ledger.filter { $0.hasPrefix("report:") }.count)",
        ].joined(separator: "|")
    }
    #endif

    private var confirmedSummary: String {
        let first = rows.first
        let chest = first?.measurements[.chestWidth] ?? "-"
        return "\(productName) · \(first?.label ?? "-") · 가슴 단면 \(chest)"
    }

    private var availableCategories: [CoorditFitLabCategory] {
        CoorditFitLabCategory.allCases.filter { $0.garmentKind == kind }
    }

    private var measurementKeys: [CoorditFitLabMeasurementKey] {
        CoorditFitLabMeasurementKey.allCases.filter { $0.garmentKind == kind }
    }

    private var classificationControls: some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            if stage == .entry {
                Toggle("링크에서 옷 종류 자동으로 찾기", isOn: $usesAutomaticCategory)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    .tint(CoorditFitLabPalette.ink)
                    .accessibilityIdentifier("fitlab-url-automatic-category")
            }
            if !usesAutomaticCategory || stage == .review {
                CoorditGarmentCategorySelector(kind: kindBinding, category: categoryBinding, metrics: metrics, identifier: "fitlab-url")
            }
        }
        .disabled(isLoading)
    }

    private var kindBinding: Binding<CoorditFitLabGarmentKind> {
        Binding(
            get: { kind },
            set: { newKind in
                guard newKind != kind else { return }
                kind = newKind
                category = newKind == .upper ? .tshirt : .pants
                if stage == .review {
                    rows = rows.map { EditableRow(id: $0.id, label: $0.label) }
                    draft.selectedReferenceIDs.removeAll()
                }
            }
        )
    }

    private var categoryBinding: Binding<CoorditFitLabCategory> {
        Binding(
            get: { category },
            set: { newCategory in
                guard newCategory != category else { return }
                category = newCategory
                kind = newCategory.garmentKind
                if stage == .review {
                    draft.selectedReferenceIDs.removeAll()
                }
            }
        )
    }

    private func completeLinkEntry() {
        focusedField = nil
        guard Self.validatedURL(from: urlText) != nil else { return }
        // 상품명 같은 문구가 같이 들어왔으면 링크만 남겨 보여준다.
        urlText = CoorditProductLinkText.extract(from: urlText)
        tutorial.advance(from: .link, to: .importLink)
    }

    private func updateTutorialForEntry() {
        guard stage == .entry else { return }
        tutorial.show(focusedField == "url" || Self.validatedURL(from: urlText) == nil ? .link : .importLink)
    }

    private func startImport() {
        focusedField = nil
        errorMessage = nil
        guard let url = Self.validatedURL(from: urlText) else {
            errorMessage = "HTTP 또는 HTTPS 상품 링크를 입력해 주세요."
            return
        }
        invalidateImport()
        guard !CoorditTutorialExample.matches(url), !Self.usesStubbedImport else {
            startServerImport(url: url)
            return
        }
        // 서버를 거치지 않고 기기에서 직접 페이지를 열어 사이즈표를 읽는다.
        // 요청이 사용자 IP로 나가 판매처 차단을 피하고, 로그인/캡차도 사용자가 그 자리에서 통과할 수 있다.
        webImportURL = url
    }

    /// UI 테스트 픽스처는 서버 응답을 대신하므로 실제 페이지를 여는 웹뷰를 건너뛴다.
    /// 픽스처 실행에서도 웹뷰를 확인하려면 `--coordit-fitlab-web-import`를 함께 넘긴다.
    private static var usesStubbedImport: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--coordit-fitlab-fixture") && !arguments.contains("--coordit-fitlab-web-import")
    }

    /// 웹뷰에서 사이즈표를 얻은 경우.
    private func completeWebImport(_ chart: CoorditWebSizeChart) {
        let url = webImportURL ?? Self.validatedURL(from: urlText)
        webImportURL = nil
        guard !chart.rows.isEmpty else {
            if let url { startServerImport(url: url) }
            return
        }
        let rows = chart.rows.map { row in
            EditableRow(
                label: row.sizeLabel,
                measurements: Dictionary(uniqueKeysWithValues: row.measurements.map { ($0.key, Self.format($0.value)) })
            )
        }
        applyWebChart(chart, editableRows: rows)
        stage = .review
        confirm(automatically: true)
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// 웹뷰 결과를 기존 review 화면 상태로 옮긴다.
    private func applyWebChart(_ chart: CoorditWebSizeChart, editableRows: [EditableRow]) {
        if usesAutomaticCategory {
            category = Self.inferredCategory(for: chart)
        }
        kind = category.garmentKind
        productName = chart.productName ?? ""
        brand = chart.brand ?? ""
        rows = editableRows.isEmpty ? [EditableRow()] : editableRows
        draft.source = .url
        draft.productFacts = nil
        draft.productURL = chart.productURL ?? Self.validatedURL(from: urlText) ?? draft.productURL
        draft.mallName = chart.mallName
        draft.selectedReferenceIDs.removeAll()
        draft.isSourceConfirmed = false
        validationMessage = nil
    }

    /// 서버가 해주던 옷 종류 자동 분류를 기기에서 대신한다.
    /// 상·하의는 표에 있는 측정 항목으로, 세부 종류는 상품명 키워드로 가른다.
    private static func inferredCategory(for chart: CoorditWebSizeChart) -> CoorditFitLabCategory {
        let keys = chart.rows.flatMap(\.measurements.keys)
        let lowerCount = keys.filter { $0.garmentKind == .lower }.count
        let kind: CoorditFitLabGarmentKind = lowerCount > keys.count - lowerCount ? .lower : .upper
        let name = (chart.productName ?? "").lowercased()
        let keywords: [(CoorditFitLabCategory, [String])] = [
            (.hoodie, ["후드", "후디", "hood"]),
            (.sweatshirt, ["맨투맨", "스웨트", "sweat"]),
            (.knit, ["니트", "스웨터", "가디건", "knit", "sweater", "cardigan"]),
            (.coat, ["코트", "coat"]),
            (.jacket, ["자켓", "재킷", "점퍼", "블루종", "패딩", "jacket", "blouson"]),
            (.shirt, ["셔츠", "블라우스", "shirt", "blouse"]),
            (.shorts, ["반바지", "쇼츠", "쇼트", "shorts"]),
            (.skirt, ["스커트", "치마", "skirt"]),
            (.jeans, ["데님", "청바지", "진", "denim", "jeans"]),
        ]
        // "티셔츠"는 "셔츠"를 포함하므로 먼저 걸러낸다.
        let isTee = ["티셔츠", "t-shirt", "tee", "반팔", "긴팔"].contains { name.contains($0) }
        if !isTee, let match = keywords.first(where: { entry in
            entry.0.garmentKind == kind && entry.1.contains { name.contains($0) }
        }) {
            return match.0
        }
        return kind == .upper ? .tshirt : .pants
    }

    private func startServerImport(url: URL) {
        invalidateImport()
        let generation = importGeneration
        isLoading = true
        importRequest = Task { @MainActor in
            do {
                let response: CoorditFitLabURLPrefillResponse
                if CoorditTutorialExample.matches(url) {
                    response = CoorditTutorialExample.product(category: category)
                } else {
                    response = try await prefill(url, usesAutomaticCategory ? nil : category)
                }
                guard !Task.isCancelled, generation == importGeneration, stage == .entry else { return }
                apply(response)
                stage = .review
                isLoading = false
                confirm(automatically: true)
            } catch let error as CoorditFitLabError {
                guard !Task.isCancelled, generation == importGeneration, stage == .entry else { return }
                errorMessage = error.errorDescription ?? "상품 정보를 가져오지 못했어요."
                isLoading = false
            } catch {
                guard !Task.isCancelled, generation == importGeneration, stage == .entry else { return }
                errorMessage = "상품 정보를 가져오지 못했어요."
                isLoading = false
            }
        }
    }

    private func invalidateImport() {
        importGeneration += 1
        importRequest?.cancel()
        importRequest = nil
        isLoading = false
    }

    private func switchToManual() {
        invalidateImport()
        onSwitchToManual()
    }

    private func switchToOCR() {
        invalidateImport()
        onSwitchToOCR()
    }

    private func applyInitialURLIfNeeded() {
        guard urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let url = initialURL ?? draft.productURL
        guard let url else { return }
        urlText = url.absoluteString
        draft.source = .url
        draft.productURL = url
        draft.isSourceConfirmed = false
        errorMessage = nil
    }

    private func apply(_ response: CoorditFitLabURLPrefillResponse) {
        kind = response.category.garmentKind
        category = response.category
        productName = response.productName
        brand = response.brand ?? ""
        rows = response.sizes.map(EditableRow.init)
        if rows.isEmpty { rows = [EditableRow()] }
        draft.source = .url
        draft.productFacts = response.productFacts
        draft.productURL = response.productUrl
        draft.mallName = response.mallName
        draft.selectedReferenceIDs.removeAll()
        draft.isSourceConfirmed = false
        validationMessage = nil
    }

    private func confirm(automatically: Bool = false) {
        focusedField = nil
        let trimmedName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !rows.isEmpty else {
            validationMessage = "상품명과 사이즈 행을 확인해 주세요."
            return
        }

        let normalizedLabels = rows.map { CoorditFitLabDraftValidation.normalizedSizeLabel($0.label) }
        let duplicateLabels = CoorditFitLabDraftValidation.duplicateSizeLabels(in: rows.map(\.label))
        var parsedRows: [CoorditFitLabSizeDraft] = []
        for (index, row) in rows.enumerated() {
            let label = row.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                validationMessage = "모든 사이즈명을 입력해 주세요."
                return
            }
            guard !duplicateLabels.contains(normalizedLabels[index]) else {
                validationMessage = "사이즈명은 중복될 수 없어요."
                return
            }
            var measurements: [CoorditFitLabMeasurementKey: Double] = [:]
            for key in measurementKeys {
                let raw = row.measurements[key, default: ""].replacingOccurrences(of: ",", with: ".")
                guard raw.isEmpty || (Double(raw).map { $0.isFinite && $0 > 0 } == true) else {
                    validationMessage = "측정값은 0보다 큰 cm 숫자여야 해요."
                    return
                }
                if let value = Double(raw), value.isFinite, value > 0 { measurements[key] = value }
            }
            guard !measurements.isEmpty else {
                validationMessage = "각 사이즈에 측정값을 하나 이상 입력해 주세요."
                return
            }
            parsedRows.append(CoorditFitLabSizeDraft(id: row.id, label: label, measurements: measurements))
        }

        if automatically, !CoorditFitLabImportAcceptance.canContinue(sizes: parsedRows, kind: kind) {
            validationMessage = "읽지 못한 치수만 확인해주세요."
            return
        }
        draft.source = .url
        draft.garmentKind = kind
        draft.category = category
        draft.productName = trimmedName
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.brand = trimmedBrand.isEmpty ? nil : trimmedBrand
        draft.sizes = parsedRows
        draft.ocrMetadata = nil
        draft.isSourceConfirmed = true
        draft.selectedReferenceIDs.removeAll()
        validationMessage = nil
        stage = .confirmed
    }

    private func rowBinding(_ id: UUID, keyPath: WritableKeyPath<EditableRow, String>) -> Binding<String> {
        Binding(
            get: { rows.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { value in
                guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
                rows[index][keyPath: keyPath] = value
                validationMessage = nil
            }
        )
    }

    private func measurementBinding(_ id: UUID, key: CoorditFitLabMeasurementKey) -> Binding<String> {
        Binding(
            get: { rows.first(where: { $0.id == id })?.measurements[key, default: ""] ?? "" },
            set: { value in
                guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
                rows[index].measurements[key] = value
                validationMessage = nil
            }
        )
    }

    private static func validatedURL(from input: String) -> URL? {
        let trimmed = CoorditProductLinkText.extract(from: input)
        let forbiddenScalars = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy({ !forbiddenScalars.contains($0) }),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.user == nil,
              components.password == nil,
              let url = components.url,
              let canonicalHost = url.host(percentEncoded: false),
              Self.isValidHost(canonicalHost)
        else { return nil }
        return url
    }

    private static func isValidHost(_ host: String) -> Bool {
        if host.contains(":") {
            var address = in6_addr()
            return host.withCString { inet_pton(AF_INET6, $0, &address) == 1 }
        }

        if host.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) || $0 == "." }) {
            var address = in_addr()
            return host.withCString { inet_pton(AF_INET, $0, &address) == 1 }
        }

        guard host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  let first = label.utf8.first,
                  let last = label.utf8.last,
                  isASCIIAlphaNumeric(first),
                  isASCIIAlphaNumeric(last)
            else { return false }
            return label.utf8.allSatisfy { isASCIIAlphaNumeric($0) || $0 == 45 }
        }
    }

    private static func isASCIIAlphaNumeric(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
    }

    private func title(for category: CoorditFitLabCategory) -> String {
        switch category {
        case .tshirt: "티셔츠"
        case .shirt: "셔츠"
        case .sweatshirt: "스웨트셔츠"
        case .hoodie: "후드"
        case .knit: "니트"
        case .jacket: "재킷"
        case .coat: "코트"
        case .pants: "팬츠"
        case .jeans: "데님"
        case .shorts: "반바지"
        case .skirt: "스커트"
        }
    }

    private func measurementTitle(for key: CoorditFitLabMeasurementKey) -> String {
        switch key {
        case .shoulderWidth: "어깨 단면"
        case .chestWidth: "가슴 단면"
        case .totalLength: "총장"
        case .sleeveLength: "소매 길이"
        case .waistWidth: "허리 단면"
        case .hipWidth: "엉덩이 단면"
        case .rise: "밑위"
        case .outseam: "바깥 총장"
        }
    }

    private enum Stage {
        case entry
        case review
        case confirmed
    }

    private struct WebImportTarget: Identifiable {
        // URL을 그대로 정체성으로 쓴다. 매번 새 UUID면 본문이 다시 그려질 때마다 웹뷰가 재생성된다.
        var id: URL { url }
        let url: URL
        init(_ url: URL) { self.url = url }
    }

    private struct EditableRow: Identifiable, Equatable {
        var id = UUID()
        var label = ""
        var measurements: [CoorditFitLabMeasurementKey: String] = [:]

        init(id: UUID = UUID(), label: String = "", measurements: [CoorditFitLabMeasurementKey: String] = [:]) {
            self.id = id
            self.label = label
            self.measurements = measurements
        }

        nonisolated init(_ source: CoorditFitLabURLPrefillResponse.Size) {
            label = source.sizeLabel
            measurements = [
                .shoulderWidth: source.shoulderWidth,
                .chestWidth: source.chestWidth,
                .totalLength: source.totalLength,
                .sleeveLength: source.sleeveLength,
                .waistWidth: source.waistWidth,
                .hipWidth: source.hipWidth,
                .rise: source.rise,
                .outseam: source.outseam,
            ].compactMapValues { value in
                value?.formatted(.number.precision(.fractionLength(0...2)))
            }
        }
    }
}
#endif
