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
    @State private var showsCameraComingSoon = false
    @State private var selectedSizeLabel: String?
    @State private var showsWardrobe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.value(14)) {
                if coordinator.draft.isTutorialExample { CoorditExampleNotice() }
                if coordinator.recommendation == nil, !coordinator.isComparisonRequested {
                    CoorditFitLabProductOverview(draft: coordinator.draft, metrics: metrics)
                    if let editProduct {
                        Button("상품 정보 수정", action: editProduct)
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                            .accessibilityIdentifier("fitlab-edit-product")
                    }
                }
                if coordinator.recommendation != nil {
                    resultPanel
                } else if coordinator.isComparisonRequested {
                    compactSelectionPanel
                }
                ledgerProbe
            }
            .padding(.horizontal, metrics.value(22))
            .padding(.bottom, metrics.value(isFreeOverview ? 24 : 120))
        }
        .coorditScrollEdgeTreatment(topFade: metrics.value(14))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFreeOverview {
                CoorditFitLabComparisonCTA(metrics: metrics) {
                    coordinator.isComparisonRequested = true
                    tutorial.show(.references)
                }
                .fitLabTutorialTarget(.continueToReferences)
                .padding(.horizontal, metrics.value(22))
                .padding(.top, metrics.value(12))
                .padding(.bottom, metrics.value(106))
                .background {
                    LinearGradient(colors: [CoorditFitLabPalette.surface.opacity(0), CoorditFitLabPalette.surface, CoorditFitLabPalette.surface], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .coorditScreenTransition(
            value: coordinator.isComparisonRequested,
            direction: coordinator.isComparisonRequested ? .forward : .backward
        )
        .sheet(isPresented: $showsWardrobe) {
            CoorditFitLabReferencePicker(coordinator: coordinator, reload: loadReferences, register: manageReferences)
        }
        .onAppear { updateTutorialSelection() }
        .onChange(of: coordinator.draft.selectedReferenceIDs) { _, _ in updateTutorialSelection() }
        .onChange(of: coordinator.references) { _, _ in updateTutorialSelection() }
        .task(id: coordinator.isComparisonRequested) {
            if coordinator.isComparisonRequested, coordinator.recommendation == nil {
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
        .alert("카메라 측정 기능은 준비 중입니다!", isPresented: $showsCameraComingSoon) {
            Button("확인", role: .cancel) { }
        }
    }

    private var isFreeOverview: Bool {
        coordinator.recommendation == nil && !coordinator.isComparisonRequested
    }

    private func updateTutorialSelection() {
        guard coordinator.recommendation == nil else { return }
        guard coordinator.isComparisonRequested else {
            tutorial.show(.continueToReferences)
            return
        }
        tutorial.show(coordinator.canSubmit ? .analyze : .references)
    }

    private var compactSelectionPanel: some View {
        VStack(alignment: .leading, spacing: metrics.value(14)) {
            Text(coordinator.draft.productName)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                .foregroundStyle(CoorditFitLabPalette.muted)
            Text(coordinator.references.isEmpty ? "잘 맞는 내 옷과 비교해요" : "어떤 옷과 비교할까요?")
                .font(CoorditTypography.gmarketBold(size: metrics.value(19), relativeTo: .title3))
                .accessibilityIdentifier("fitlab-reference-selection")

            if !coordinator.draft.isTutorialExample {
                CoorditInputMethodPanel(metrics: metrics) {
                CoorditInputMethodCard(title: "내 옷 링크로 등록", subtitle: "잘 맞는 옷의 상품 링크 사용", symbol: "link", metrics: metrics, action: manageReferences)
                    .accessibilityIdentifier("fitlab-manage-references")
                if CoorditGarmentCaptureController.featureEnabled, let measureWithCamera {
                    CoorditInputMethodCard(title: "촬영해서 비교", subtitle: "사진과 치수는 옷장에 자동 저장", symbol: "camera", metrics: metrics, action: measureWithCamera)
                        .accessibilityIdentifier("fitlab-camera-comparison")
                } else {
                    CoorditInputMethodCard(title: "카메라로 등록", subtitle: "내 옷을 촬영해 치수 측정", symbol: "camera", metrics: metrics) {
                        showsCameraComingSoon = true
                    }
                    .accessibilityIdentifier("fitlab-camera-comparison")
                }
                }
            }
            CoorditInputMethodPanel(metrics: metrics) {
                CoorditInputMethodCard(title: "옷장에서 골라 비교", subtitle: "이미 등록한 내 옷 사용", symbol: "tshirt", metrics: metrics) {
                    showsWardrobe.toggle()
                }
                .accessibilityIdentifier("fitlab-choose-closet")
                .accessibilityHint("팝업에서 비교할 옷을 선택해요")
            }
            if !coordinator.draft.selectedReferenceIDs.isEmpty {
                Text("선택한 기준 옷 \(coordinator.draft.selectedReferenceIDs.count)벌 · " + coordinator.references.filter {
                    coordinator.draft.selectedReferenceIDs.contains($0.id)
                }.map { $0.nickname ?? "기준 옷" }.joined(separator: ", "))
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fitlab-selected-reference-summary")
            }
            Text("내 옷과 비교하고 상세 리포트를 만들 때 실타래 1개를 사용해요. 링크 등록과 1차 분석은 무료예요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("fitlab-comparison-cost")
            Button(coordinator.retryStep == nil ? "비교하기 · 실타래 1개" : "다시 시도", action: submit)
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                .disabled(!coordinator.canSubmit || coordinator.loadState == .loading)
                .accessibilityIdentifier(coordinator.retryStep == nil ? "fitlab-submit-analysis" : "fitlab-retry-submission")
            if let error = coordinator.error { errorPanel(error) }
            Button("다른 상품 넣기") { showsDiscardConfirmation = true }
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
        }
        .fitLabTutorialTarget(coordinator.canSubmit ? .analyze : .references)
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
