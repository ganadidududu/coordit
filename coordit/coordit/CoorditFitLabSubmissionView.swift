import SwiftUI

#if os(iOS)
struct CoorditFitLabSubmissionView: View {
    @EnvironmentObject private var tutorial: CoorditFitLabTutorial
    let metrics: CoorditResponsiveMetrics
    @ObservedObject var coordinator: CoorditFitLabCoordinator
    let requestLedger: () -> [String]
    let loadReferences: () async -> Void
    let manageReferences: () -> Void
    let submit: () -> Void
    var measureWithCamera: (() -> Void)? = nil
    var editProduct: (() -> Void)? = nil

    @State private var showsDiscardConfirmation = false
    @State private var selectedSizeLabel: String?
    @State private var showsWardrobe = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.value(14)) {
                if coordinator.draft.isTutorialExample { CoorditExampleNotice() }
                if coordinator.recommendation == nil, !coordinator.draft.isTutorialExample {
                    CoorditFitLabProductOverview(draft: coordinator.draft, metrics: metrics)
                    if let editProduct {
                        Button("상품 정보 수정", action: editProduct)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                            .foregroundStyle(CoorditFitLabPalette.muted)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("fitlab-edit-product")
                    }
                }
                if coordinator.recommendation != nil {
                    resultPanel
                } else {
                    compactSelectionPanel
                }
                ledgerProbe
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(120))
        }
        .coorditScrollEdgeTreatment(topFade: metrics.value(14))
        .onAppear { updateTutorialSelection() }
        .onChange(of: coordinator.draft.selectedReferenceIDs) { _, _ in updateTutorialSelection() }
        .onChange(of: coordinator.references) { _, _ in updateTutorialSelection() }
        .task {
            if coordinator.references.isEmpty, coordinator.recommendation == nil {
                await loadReferences()
            }
        }
        .onChange(of: coordinator.recommendation?.fitAnalysisResultID) { _, _ in
            selectedSizeLabel = nil
        }
        .alert("새 상품을 등록할까요?", isPresented: $showsDiscardConfirmation) {
            Button("계속 입력", role: .cancel) { }
            Button("새 상품 등록", role: .destructive) {
                coordinator.discardAndRestart()
            }
        } message: {
            Text("현재 입력한 상품 정보, 기준 의류 선택, 아직 저장하지 않은 분석 결과는 초기화돼요. 이미 저장된 분석 기록은 그대로 남아요.")
        }
    }

    private func updateTutorialSelection() {
        guard coordinator.recommendation == nil else { return }
        tutorial.show(coordinator.canSubmit ? .analyze : .references)
    }

    private var compactSelectionPanel: some View {
        VStack(alignment: .leading, spacing: metrics.value(14)) {
            Text(coordinator.references.isEmpty ? "잘 맞는 내 옷과 비교해요" : "어떤 옷과 비교할까요?")
                .font(CoorditTypography.gmarketBold(size: metrics.value(19), relativeTo: .title3))
                .accessibilityIdentifier("fitlab-reference-selection")

            if !coordinator.draft.isTutorialExample {
                CoorditInputMethodPanel(metrics: metrics) {
                if CoorditGarmentCaptureController.featureEnabled, [.tshirt, .pants].contains(coordinator.draft.category), let measureWithCamera {
                    CoorditInputMethodCard(title: "촬영해서 비교", subtitle: "사진과 치수는 옷장에 자동 저장", symbol: "camera", metrics: metrics, action: measureWithCamera)
                        .accessibilityIdentifier("fitlab-camera-comparison")
                }
                CoorditInputMethodCard(title: "옷장에서 골라 비교", subtitle: "이미 등록한 내 옷 사용", symbol: "tshirt", metrics: metrics) {
                    showsWardrobe.toggle()
                }
                .accessibilityIdentifier("fitlab-choose-closet")
                .accessibilityValue(showsWardrobe ? "펼쳐짐" : "접힘")
                }
            }
            if showsWardrobe || coordinator.draft.isTutorialExample {
                if coordinator.loadState == .loading { ProgressView("불러오는 중") }
                ForEach(coordinator.references) { reference in referenceButton(reference) }
                if !coordinator.draft.isTutorialExample {
                    if coordinator.references.isEmpty, coordinator.loadState != .loading {
                        Text("비교할 옷이 아직 없어요.")
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                            .foregroundStyle(CoorditFitLabPalette.muted)
                    }
                    CoorditCompactActionButton(title: "내 옷 링크로 추가", symbol: "link", metrics: metrics, action: manageReferences)
                        .accessibilityIdentifier("fitlab-manage-references")
                }
            }
            if !coordinator.draft.selectedReferenceIDs.isEmpty {
                Button(coordinator.retryStep == nil ? "비교하기 · 실타래 1개" : "다시 시도", action: submit)
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                    .disabled(!coordinator.canSubmit || coordinator.loadState == .loading)
                    .accessibilityIdentifier(coordinator.retryStep == nil ? "fitlab-submit-analysis" : "fitlab-retry-submission")
            }
            if let error = coordinator.error { errorPanel(error) }
            Button("다른 상품 넣기") { showsDiscardConfirmation = true }
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .frame(minHeight: 44)
        }
        .fitLabTutorialTarget(coordinator.canSubmit ? .analyze : .references)
    }

    private func referenceButton(_ reference: CoorditFitLabReferenceRow) -> some View {
        let selected = coordinator.draft.selectedReferenceIDs.contains(reference.id)
        return Button {
            coordinator.toggleReference(reference)
        } label: {
            HStack(spacing: metrics.value(12)) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(CoorditFitLabPalette.ink)
                VStack(alignment: .leading, spacing: metrics.value(3)) {
                    Text(reference.nickname ?? "기준 옷")
                        .font(CoorditTypography.gmarketBold(size: metrics.value(13), relativeTo: .body))
                    Text(reference.fitType)
                        .font(CoorditTypography.gmarketLight(size: metrics.value(11), relativeTo: .caption))
                }
                Spacer()
            }
            .foregroundStyle(Color.black)
            .padding(metrics.value(12))
            .background(selected ? CoorditFitLabPalette.empty : CoorditFitLabPalette.field)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        }
        .coorditPressFeedback()
        .disabled(coordinator.loadState == .loading)
        .accessibilityIdentifier("fitlab-reference-\(reference.id)")
        .accessibilityValue(selected ? "선택됨" : "선택 안 됨")
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: metrics.value(14)) {
            if CoorditGarmentCaptureController.featureEnabled, coordinator.cameraMeasurement != nil, let measureWithCamera {
                Button("AR·사진 비교 다시 열기 · 추가 차감 없음", action: measureWithCamera)
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                    .accessibilityIdentifier("fitlab-reopen-camera")
            }
            if let recommendation = coordinator.recommendation {
                Text("핏 분석이 준비됐어요")
                    .font(CoorditTypography.gmarketBold(size: metrics.value(20), relativeTo: .title3))
                    .foregroundStyle(Color.black)
                Text("추천 \(recommendation.recommendedSize) · \(CoorditFitLabResultMeasurement.score(recommendation.fitScore))점")
                    .font(CoorditTypography.gmarketBold(size: metrics.value(17), relativeTo: .headline))
                    .foregroundStyle(Color.black)
                    .accessibilityLabel("추천 \(recommendation.recommendedSize) · \(CoorditFitLabResultMeasurement.score(recommendation.fitScore))점")
                    .accessibilityIdentifier("fitlab-submission-result")

                let variant: CoorditFitLabResultVariant = coordinator.draft.garmentKind == .upper ? .top : .bottom
                let sizeOptions = CoorditFitLabSizeOption.makeOptions(
                    variant: variant,
                    recommendation: recommendation,
                    report: coordinator.report,
                    sizeDrafts: coordinator.draft.sizes
                )
                let selectedSize = sizeOptions.first { $0.sizeLabel == selectedSizeLabel }
                    ?? sizeOptions.first { $0.isRecommended }
                    ?? sizeOptions.first
                let scoreCard = CoorditFitLabScoreCard(
                    variant: variant,
                    selectedSize: selectedSize,
                    metrics: metrics
                )
                let selection = CoorditFitLabScoreSelection(selected: selectedSize, recommendation: recommendation, report: coordinator.report)
                scoreCard
                CoorditFitLabMannequinPanel(
                    assetName: variant.assetName,
                    metrics: metrics,
                    measurements: scoreCard.measurements
                )
                .frame(height: metrics.value(270))
                CoorditFitLabOverlayLegend(metrics: metrics)
                CoorditFitLabSizeScoreChart(
                    options: sizeOptions,
                    selectedSizeLabel: $selectedSizeLabel,
                    metrics: metrics
                )
                CoorditFitLabComparisonNote(selected: selection.sizeLabel, recommended: recommendation.recommendedSize, missingScores: !selection.isRecommended && selection.measurementScores.isEmpty, metrics: metrics)
                CoorditFitLabPointScoreChart(scores: selection.fitPointScores, metrics: metrics)
                CoorditFitLabMeasurementScoreChart(scores: selection.measurementScores, metrics: metrics)
                CoorditFitLabDifferenceChart(measurements: scoreCard.measurements, metrics: metrics)
                CoorditFitLabReportCard(
                    report: coordinator.report,
                    fallbackMessage: nil,
                    metrics: metrics,
                    recommendedSize: recommendation.recommendedSize
                )
            }

            Button("새 상품 등록하기") {
                showsDiscardConfirmation = true
            }
            .buttonStyle(
                CoorditContentActionButtonStyle(
                    prominence: .secondary,
                    height: metrics.value(48),
                    cornerRadius: metrics.value(7),
                    fontSize: metrics.value(13)
                )
            )
            .disabled(coordinator.loadState == .loading)
            .accessibilityIdentifier("fitlab-discard-submission")
        }
        .padding(metrics.value(18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
        .overlay(RoundedRectangle(cornerRadius: metrics.value(8)).stroke(Color.black.opacity(0.12)))
    }

    private func errorPanel(_ error: CoorditFitLabError) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(5)) {
            Text("\(stepTitle) 단계에서 멈췄어요")
                .font(CoorditTypography.gmarketBold(size: metrics.value(13), relativeTo: .headline))
            Text(error.errorDescription ?? "다시 시도해 주세요.")
                .font(CoorditTypography.gmarketLight(size: metrics.value(12), relativeTo: .body))
        }
        .foregroundStyle(Color.black)
        .padding(metrics.value(11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.empty.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fitlab-submission-error")
    }

    private var stepTitle: String {
        switch coordinator.retryStep {
        case .creatingProduct: "상품 저장"
        case .creatingSizes: "사이즈 저장"
        case .recommending: "핏 추천"
        case .generatingReport: "상세 리포트"
        case .loadingReferences: "기준 옷 불러오기"
        default: "핏 분석"
        }
    }

    @ViewBuilder
    private var ledgerProbe: some View {
        #if DEBUG
        VStack {
            Text(ledgerSummary)
                .accessibilityIdentifier("fitlab-submission-ledger")
            Text(requestLedger().joined(separator: "|"))
                .accessibilityIdentifier("fitlab-submission-ledger-detail")
        }
        .font(.system(size: 1))
        .frame(width: 1, height: 1)
        .opacity(0.01)
        #endif
    }

    private var ledgerSummary: String {
        let ledger = requestLedger()
        func count(_ exact: String) -> Int { ledger.filter { $0 == exact }.count }
        return [
            "references=\(ledger.filter { $0.hasPrefix("references:") }.count)",
            "product=\(count("create-product"))",
            "M-attempts=\(count("create-size:M:attempt"))",
            "M-success=\(count("create-size:M:success"))",
            "L-attempts=\(count("create-size:L:attempt"))",
            "L-success=\(count("create-size:L:success"))",
            "recommend=\(count("recommend"))",
            "report=\(ledger.filter { $0.hasPrefix("report:") }.count)",
        ].joined(separator: "|")
    }
}
#endif
