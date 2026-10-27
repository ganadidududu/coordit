import SwiftUI
import PhotosUI
import AVFoundation

#if os(iOS)
struct CoorditFitLabCameraComparison: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var coordinator: CoorditFitLabCoordinator
    let analyze: (CoorditGarmentMeasurement) async throws -> Void
    @ObservedObject var capture: CoorditGarmentCaptureController
    @StateObject private var cameraMotion = CoorditCameraMotion()
    var savesReferenceOnly = false
    #if DEBUG
    var fieldTestSession: CoorditARFieldTestSession?
    #endif
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var isAnalyzing = false
    @State private var failureMessage: String?
    @State private var selectedSize: String?
    @State private var showsCloseConfirmation = false
    @State private var showsDiscardMeasurement = false
    @State private var showsAIProcessingConsent = false
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @GestureState private var isMagnifyingPhoto = false
    @State private var photoScale: CGFloat = 1
    @State private var accumulatedPhotoScale: CGFloat = 1
    @State private var photoOffset = CGSize.zero
    @State private var accumulatedPhotoOffset = CGSize.zero
    @State private var draggedOrigins: [Int: CoorditMeasurementPoint] = [:]

    private var isUnlocked: Bool {
        coordinator.report != nil && coordinator.cameraMeasurement?.id == capture.identifier
    }
    private var candidate: CoorditFitLabSizeDraft? {
        coordinator.draft.sizes.first { $0.label == (selectedSize ?? coordinator.recommendation?.recommendedSize) } ?? coordinator.draft.sizes.first
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = CoorditResponsiveMetrics(size: geometry.size)
            ScrollView {
                VStack(alignment: .leading, spacing: metrics.value(16)) {
                    CoorditFitLabTitleCard(title: "촬영", metrics: metrics) {
                        if isAnalyzing { showsCloseConfirmation = true } else { dismiss() }
                    }
                    introduction(metrics)
                    if CoorditGarmentCaptureController.supportsLiDAR || CoorditGarmentCaptureController.supportsCardlessAR, capture.image == nil {
                        methodPicker(metrics).disabled(isAnalyzing || isUnlocked)
                    }
                    if capture.method == .card, capture.image == nil {
                        cardSourceControls(metrics)
                            .disabled(isAnalyzing || isUnlocked)
                    }
                    if capture.image != nil || capture.method.usesAR { measurementReadout(metrics) }
                    if capture.image != nil, !isUnlocked {
                        recognitionControls
                        Text(capture.instruction)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("camera-fit-instruction")
                    }
                    captureSurface(metrics)
                    if capture.image != nil || capture.method.usesAR { measurementControls(metrics) }
                    if capture.image != nil, !isUnlocked, coordinator.landmarkGateway != nil {
                        Button("AI로 측정점 제안받기 · 실험 기능") { showsAIProcessingConsent = true }
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                            .disabled(capture.isDetecting || isAnalyzing)
                    }
                    if isUnlocked { comparisonControls(metrics) }
                    if !isUnlocked, capture.isComplete { measurementConfirmation(metrics) }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--coordit-ui-testing") {
                        Button("테스트 사진으로 측정하기") { capture.loadTestFixture() }
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                            .accessibilityIdentifier("camera-fit-test-fixture")
                        Button("자동 인식 테스트") { capture.loadTestFixture(automatic: true) }
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                            .accessibilityIdentifier("camera-fit-test-auto")
                    }
                    #endif
                }
                .padding(metrics.value(16))
                .padding(.bottom, metrics.value(24))
            }
            .clipped()
            .background(CoorditDesignTokens.ColorToken.appBackground)
            .foregroundStyle(CoorditFitLabPalette.ink)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: metrics.value(8)) {
                    if let message = failureMessage ?? capture.message {
                        Text(message)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                            .foregroundStyle(CoorditDesignTokens.ColorToken.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("camera-fit-error")
                    }
                    bottomAction(metrics)
                }
                .padding(.horizontal, metrics.value(16))
                .padding(.vertical, metrics.value(10))
                .background(CoorditDesignTokens.ColorToken.appBackground)
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isAnalyzing)
        .fullScreenCover(isPresented: $showsCamera) {
            #if DEBUG && targetEnvironment(simulator)
            CoorditGarmentCameraOverlay(category: capture.category, takePhoto: {
                showsCamera = false
                capture.loadGuideTestFixture()
            }, cancel: { showsCamera = false })
            .background(.black)
            .overlay(alignment: .top) {
                Text("시뮬레이터 · 촬영 미리보기")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.top, 48)
                    .allowsHitTesting(false)
            }
            #else
            CoorditGuidedGarmentCamera(category: capture.category) { image in
                showsCamera = false
                if let image { capture.setImage(image) }
            }
            .ignoresSafeArea()
            #endif
        }
        .task(id: selectedPhoto) {
            guard let photo = selectedPhoto else { return }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                    throw CoorditFitLabError.invalidDraft("사진을 불러오지 못했어요.")
                }
                guard !Task.isCancelled else { return }
                capture.setImage(image)
            } catch { failureMessage = error.localizedDescription }
        }
        .task {
            if capture.method.usesAR { cameraMotion.start(); await requestCameraPermission() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { capture.stop(); cameraMotion.stop() }
            else if cameraAuthorized {
                capture.resume()
                if capture.method.usesAR { cameraMotion.start() }
            }
        }
        .onChange(of: capture.method) { _, method in
            if method.usesAR { cameraMotion.start() } else { cameraMotion.stop() }
        }
        .onChange(of: capture.image) { _, _ in
            photoScale = 1; accumulatedPhotoScale = 1; photoOffset = .zero; accumulatedPhotoOffset = .zero
        }
        .onDisappear { capture.stop(); cameraMotion.stop() }
        .alert("AI 측정점 처리를 위해 사진을 전송할까요?", isPresented: $showsAIProcessingConsent) {
            Button("동의하고 이번 사진 처리") {
                if let gateway = coordinator.landmarkGateway { capture.requestAILandmarks(using: gateway) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("위치정보를 제거한 사진을 Coordit 독립 AI 서버에서 일시 처리해요. 처리 후 사진을 보관하지 않으며 학습에 사용하지 않아요. 제안된 점은 직접 확인하고 보정해주세요.")
        }
        .alert("분석은 계속 진행돼요", isPresented: $showsCloseConfirmation) {
            Button("화면에 머물기", role: .cancel) {}
            Button("닫기") { dismiss() }
        } message: { Text("완료된 상세 리포트는 핏 랩에서 확인할 수 있어요.") }
        .alert("새로 측정할까요?", isPresented: $showsDiscardMeasurement) {
            Button("유지하기", role: .cancel) {}
            Button("새로 측정") { capture.reset(); failureMessage = nil }
        } message: { Text("같은 옷을 다시 측정하면 현재 분석 묶음에서 비교와 리포트를 갱신해요. 다른 옷은 새 분석으로 시작해주세요.") }
    }

    private func introduction(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(8)) {
            Text(isUnlocked ? "내 옷과 겹쳐보기" : (capture.image == nil ? "잘 맞는 내 옷을 촬영해요" : "측정선을 확인해주세요"))
                .font(CoorditTypography.gmarketBold(size: metrics.value(20), relativeTo: .title3))
                .accessibilityIdentifier("camera-fit-screen")
            Text(capture.image == nil ? capture.category.captureInstruction : "\(capture.category.koreanTitle) · 추정 치수 · cm")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .foregroundStyle(CoorditFitLabPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if isUnlocked {
                Label("사진과 치수를 옷장에 저장했어요", systemImage: "checkmark.circle.fill")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("camera-fit-closet-saved")
            }
        }
        .padding(metrics.value(16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoorditFitLabPalette.surface, in: RoundedRectangle(cornerRadius: metrics.value(8)))
    }

    private func methodPicker(_ metrics: CoorditResponsiveMetrics) -> some View {
        let layout = CoorditGarmentCaptureController.supportsCardlessAR
            ? AnyLayout(VStackLayout(spacing: metrics.value(8)))
            : AnyLayout(HStackLayout(spacing: metrics.value(8)))
        return layout {
            if CoorditGarmentCaptureController.supportsCardlessAR {
                Button("카드 없이 촬영 · 실험 기능") { capture.selectMethod(.arPlane); Task { await requestCameraPermission() } }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: capture.method == .arPlane ? .primary : .secondary))
                    .accessibilityIdentifier("camera-fit-ar-plane-method")
            }
            if CoorditGarmentCaptureController.supportsLiDAR {
                Button("LiDAR로 측정") { capture.selectMethod(.lidar); Task { await requestCameraPermission() } }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: capture.method == .lidar ? .primary : .secondary))
                    .accessibilityIdentifier("camera-fit-lidar-method")
            }
            Button("카드와 함께 촬영") { capture.selectMethod(.card) }
                .buttonStyle(CoorditContentActionButtonStyle(prominence: capture.method == .card ? .primary : .secondary))
                .accessibilityIdentifier("camera-fit-card-method")
        }
    }

    private func cardSourceControls(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            Text("옷 옆에 신용·체크카드 뒷면을 놓고 위에서 찍어주세요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: metrics.value(8)) {
                Button("촬영하기") {
                    #if DEBUG && targetEnvironment(simulator)
                    if ProcessInfo.processInfo.arguments.contains("--coordit-ui-testing") {
                        showsCamera = true
                        return
                    }
                    #endif
                    Task {
                        await requestCameraPermission()
                        if cameraAuthorized && UIImagePickerController.isSourceTypeAvailable(.camera) { showsCamera = true }
                        else { failureMessage = "카메라를 사용할 수 없어요. 사진에서 선택하거나 설정에서 카메라 권한을 확인해주세요." }
                    }
                }
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                .accessibilityIdentifier("camera-fit-take-photo")
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Text("사진에서 선택") }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                    .accessibilityIdentifier("camera-fit-select-photo")
            }
        }
    }

    @ViewBuilder
    private func captureSurface(_ metrics: CoorditResponsiveMetrics) -> some View {
        if capture.method.usesAR, capture.image == nil, cameraAuthorized {
            GeometryReader { geometry in
                ZStack {
                    CoorditLiDARCameraView(controller: capture)
                        .id(capture.method.rawValue)
                    measurementOverlay(size: geometry.size)
                        .allowsHitTesting(false)
                    if !capture.trackingReady {
                        Text("옷을 위에서 천천히 비춰주세요")
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                            .padding(12)
                            .background(CoorditFitLabPalette.surface, in: RoundedRectangle(cornerRadius: 7))
                    }
                    VStack {
                        Spacer()
                        Text(cameraMotion.posture.text)
                            .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                            .padding(12)
                            .background(CoorditFitLabPalette.surface, in: Capsule())
                            .padding(12)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: metrics.value(400))
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
            .accessibilityIdentifier("camera-fit-lidar-viewport")
        } else if let image = capture.image {
            GeometryReader { geometry in
                ZStack {
                    ZStack {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel("측정 사진. 표시된 점을 끌어서 조정하세요")
                            .accessibilityIdentifier("camera-fit-photo-viewport")
                            .accessibilityValue("\(Int(photoScale * 100))% 확대")
                            .gesture(DragGesture(minimumDistance: 12, coordinateSpace: .named("camera-photo-viewport"))
                                .onChanged { value in
                                    guard photoScale > 1, !isMagnifyingPhoto, draggedOrigins.isEmpty else { return }
                                    photoOffset = .init(width: accumulatedPhotoOffset.width + value.translation.width,
                                                        height: accumulatedPhotoOffset.height + value.translation.height)
                                }.onEnded { _ in
                                    if !isMagnifyingPhoto { accumulatedPhotoOffset = photoOffset }
                                }, including: photoScale > 1 ? .all : .none)
                        measurementOverlay(size: geometry.size)
                        if capture.isComplete, !isUnlocked, !isAnalyzing {
                            endpointHandles(size: geometry.size)
                        }
                        if capture.selection == .card, !isUnlocked, !isAnalyzing {
                            cardHandles(size: geometry.size)
                        }
                    }
                    .scaleEffect(photoScale)
                    .offset(photoOffset)
                }
                .coordinateSpace(name: "camera-photo-viewport")
                .clipped()
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture(coordinateSpace: .named("camera-photo-viewport")).onEnded { tap in
                    guard !isAnalyzing, !isUnlocked, !capture.isDetecting else { return }
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let x = ((tap.location.x - center.x - photoOffset.width) / photoScale + center.x) / geometry.size.width
                    let y = ((tap.location.y - center.y - photoOffset.height) / photoScale + center.y) / geometry.size.height
                    capture.tapImage(.init(x: x, y: y))
                })
                .simultaneousGesture(MagnifyGesture().updating($isMagnifyingPhoto) { _, active, _ in active = true }
                    .onChanged { value in photoScale = min(5, max(1, accumulatedPhotoScale * value.magnification)) }
                    .onEnded { _ in accumulatedPhotoScale = photoScale })
                .onChange(of: isMagnifyingPhoto) { _, active in
                    if active { photoOffset = accumulatedPhotoOffset }
                }
            }
            .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(8)))
        } else {
            EmptyView()
        }
    }

    private var recognitionControls: some View {
        HStack(spacing: 8) {
            if capture.method == .card {
                Button { capture.select(.card) } label: {
                    Label("카드", systemImage: capture.selection == .card ? "hand.tap.fill" : "creditcard")
                }
                .accessibilityIdentifier("camera-fit-select-card")
            }
            Button { capture.select(.garment) } label: {
                Label("옷", systemImage: capture.selection == .garment ? "hand.tap.fill" : "tshirt")
            }
            .accessibilityIdentifier("camera-fit-select-garment")
            Spacer(minLength: 0)
            Menu {
                if capture.method == .card { Button("카드 모서리 직접 지정") { capture.beginManualCard() } }
                Button("옷 측정점 직접 지정") { capture.beginManualGarment() }
            } label: {
                Label("직접 보정", systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("camera-fit-manual-correction")
        }
        .font(CoorditTypography.gmarketMedium(size: 12, relativeTo: .caption))
        .buttonStyle(.bordered)
        .tint(CoorditFitLabPalette.ink)
        .disabled(capture.isDetecting || isAnalyzing)
    }

    private func cardHandles(size: CGSize) -> some View {
        ForEach(Array(capture.corners.enumerated()), id: \.offset) { index, point in
            Circle().fill(.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(CoorditDesignTokens.ColorToken.blue, lineWidth: 3))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .scaleEffect(1 / photoScale)
                .position(x: point.x * size.width, y: point.y * size.height)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("camera-photo-viewport")).onChanged { value in
                    let key = index + 100
                    let origin = draggedOrigins[key] ?? point
                    draggedOrigins[key] = origin
                    capture.moveCardCorner(index, to: .init(x: origin.x + value.translation.width / size.width / photoScale,
                                                          y: origin.y + value.translation.height / size.height / photoScale))
                }.onEnded { _ in draggedOrigins[index + 100] = nil })
                .accessibilityLabel("카드 모서리 \(index + 1)")
                .accessibilityIdentifier("camera-fit-card-corner-\(index)")
        }
    }

    private func measurementOverlay(size: CGSize) -> some View {
        Canvas { context, canvas in
            func screen(_ point: CoorditMeasurementPoint) -> CGPoint { .init(x: point.x * canvas.width, y: point.y * canvas.height) }
            if capture.outline.count > 2 {
                var outline = Path()
                outline.addLines(capture.outline.map(screen))
                outline.closeSubpath()
                context.stroke(outline, with: .color(CoorditDesignTokens.ColorToken.blue.opacity(0.7)), lineWidth: 1)
            }
            if capture.corners.count == 4 {
                var border = Path()
                border.addLines(capture.corners.map(screen)); border.closeSubpath()
                context.stroke(border, with: .color(CoorditDesignTokens.ColorToken.blue), lineWidth: 2)
            }
            for (index, point) in capture.corners.enumerated() {
                let position = screen(point)
                context.fill(Path(ellipseIn: CGRect(x: position.x - 6, y: position.y - 6, width: 12, height: 12)), with: .color(CoorditFitLabPalette.ink))
                context.draw(Text("\(index + 1)").font(.system(size: 11, weight: .bold)).foregroundColor(.white), at: position)
            }
            for dimension in capture.dimensions {
                guard let segment = capture.segments[dimension], let start = capture.project(segment.start), let end = capture.project(segment.end) else { continue }
                var reference = Path(); reference.move(to: screen(start)); reference.addLine(to: screen(end))
                context.stroke(reference, with: .color(CoorditFitLabPalette.ink), style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
                for point in [start, end] { context.fill(Path(ellipseIn: CGRect(x: screen(point).x - 5, y: screen(point).y - 5, width: 10, height: 10)), with: .color(CoorditFitLabPalette.ink)) }
                guard isUnlocked, let key = CoorditFitLabMeasurementKey(rawValue: dimension.measurementKey), let target = candidate?.measurements[key],
                      let resized = segment.resized(centimeters: target, centered: [.chest, .shoulder, .waist, .hip].contains(dimension)),
                      let targetStart = capture.project(resized.start), let targetEnd = capture.project(resized.end) else { continue }
                var product = Path(); product.move(to: screen(targetStart)); product.addLine(to: screen(targetEnd))
                let color = target >= segment.centimeters ? CoorditDesignTokens.ColorToken.blue : CoorditDesignTokens.ColorToken.red
                context.stroke(product, with: .color(color), lineWidth: 4)
            }
            if capture.points.count % 2 == 1, let point = capture.points.last, let last = capture.project(point) {
                let p = screen(last)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(CoorditFitLabPalette.ink))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func endpointHandles(size: CGSize) -> some View {
        ForEach(Array(capture.points.enumerated()), id: \.offset) { index, point in
            if let projected = capture.project(point) {
                Circle()
                    .fill(CoorditFitLabPalette.surface)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(CoorditFitLabPalette.ink, lineWidth: 3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .scaleEffect(1 / photoScale)
                    .position(x: projected.x * size.width, y: projected.y * size.height)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("camera-photo-viewport")).onChanged { value in
                        let origin = draggedOrigins[index] ?? projected
                        draggedOrigins[index] = origin
                        let x = origin.x + value.translation.width / size.width / photoScale
                        let y = origin.y + value.translation.height / size.height / photoScale
                        capture.moveEndpoint(index, to: .init(x: x, y: y))
                    }.onEnded { _ in draggedOrigins[index] = nil })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(capture.dimensions[index / 2].title) \(index % 2 == 0 ? "시작점" : "끝점")")
                    .accessibilityIdentifier("camera-fit-point-\(index)")
            }
        }
    }

    private func measurementControls(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            if capture.method == .lidar { Text(capture.instruction)
                .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("camera-fit-instruction") }
            if capture.isDetecting { ProgressView() }
            if capture.method == .card, !capture.isDetecting {
                HStack(spacing: 16) {
                    Label(capture.calibration == nil ? "카드 위치 확인" : "카드 인식", systemImage: capture.calibration == nil ? "viewfinder" : "checkmark.circle.fill")
                    Label(capture.hasAutomaticProposal ? "치수 추정 완료" : "측정점 확인", systemImage: capture.hasAutomaticProposal ? "checkmark.circle.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                }
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .accessibilityIdentifier("camera-fit-detection-status")
            }
            if capture.method == .arPlane, capture.image == nil, !isUnlocked {
                Text(capture.instruction)
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                    .fixedSize(horizontal: false, vertical: true)
                Button("평면 위의 옷 촬영") { capture.captureARPlane() }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
                    .disabled(!capture.trackingReady || capture.isDetecting)
                    .accessibilityIdentifier("camera-fit-ar-plane-shutter")
            }
            if capture.method == .lidar, !isUnlocked {
                Button("자동으로 측정선 찾기") { capture.detectLiDAROutline() }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                    .disabled(!capture.trackingReady || capture.isDetecting)
            }
            HStack(spacing: metrics.value(8)) {
                if !isUnlocked && !capture.isComplete {
                    Button("마지막 점 취소") { capture.undo() }
                        .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                        .disabled(isAnalyzing || capture.isDetecting || (capture.points.isEmpty && capture.corners.isEmpty))
                }
                Button("다시 촬영") { capture.clearCapture(); selectedPhoto = nil }
                    .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
                    .disabled(isAnalyzing)
                    .accessibilityIdentifier("camera-fit-remeasure")
            }
        }
    }

    private func measurementReadout(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if capture.isDetecting {
                ProgressView("옷과 카드를 찾고 있어요")
                    .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
            }
            HStack(spacing: metrics.value(8)) {
                ForEach(capture.dimensions) { dimension in
                    VStack(spacing: 5) {
                        Text(dimension.title).font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                        Text(capture.segments[dimension].map { String(format: "%.1f", $0.centimeters) } ?? "—")
                            .font(CoorditTypography.gmarketBold(size: metrics.value(15), relativeTo: .body))
                    }
                    .frame(maxWidth: .infinity, minHeight: metrics.value(60))
                    .background(CoorditFitLabPalette.field, in: RoundedRectangle(cornerRadius: metrics.value(7)))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("camera-fit-measurement-\(dimension.rawValue)")
                }
            }
        }
    }

    private func measurementConfirmation(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            DisclosureGroup("측정 기준") {
            Text(capture.isLower ? "허리부터 밑단까지" : "목 옆 어깨점부터 밑단까지")
                .font(CoorditTypography.gmarketBold(size: metrics.value(13), relativeTo: .body))
            if !capture.isLower {
            Menu {
                Picker("총장 시작점", selection: $capture.lengthBasis) {
                    Text("목 옆 어깨점 → 밑단").tag("high_shoulder_to_hem")
                    Text("뒷목 중심 → 밑단").tag("back_neck_to_hem")
                }
            } label: {
                HStack {
                    Text(capture.lengthBasis == "high_shoulder_to_hem" ? "목 옆 어깨점 → 밑단" : "뒷목 중심 → 밑단")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: metrics.value(8))
                    Image(systemName: "chevron.up.chevron.down")
                }
                .padding(.vertical, metrics.value(8))
            }
            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
            .accessibilityLabel("총장 시작점")
            .accessibilityValue(capture.lengthBasis == "high_shoulder_to_hem" ? "목 옆 어깨점 → 밑단" : "뒷목 중심 → 밑단")
            }
            Text("가슴은 단면, 소매는 어깨 봉제선부터 재요. 기준이 다르면 사이즈표를 확인하고 측정점을 맞춰주세요.")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .foregroundStyle(CoorditFitLabPalette.muted)
            }
            .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
            .tint(CoorditFitLabPalette.ink)
        }
        .disabled(isAnalyzing)
    }

    private func comparisonControls(_ metrics: CoorditResponsiveMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.value(10)) {
            Text("비교 중 \(candidate?.label ?? "")")
                .font(CoorditTypography.gmarketBold(size: metrics.value(16), relativeTo: .headline))
                .accessibilityIdentifier("camera-fit-unlocked")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(coordinator.draft.sizes) { size in
                        Button(size.label) { selectedSize = size.label }
                            .buttonStyle(CoorditContentActionButtonStyle(prominence: candidate?.id == size.id ? .primary : .secondary))
                            .frame(minWidth: 64)
                            .accessibilityIdentifier("camera-fit-size-\(size.label)")
                    }
                }
            }
            Text("점선: 내 옷 · 실선: 구매 후보\n파랑: 더 넓거나 길어요 · 빨강: 더 좁거나 짧아요")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(11), relativeTo: .caption))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(capture.dimensions) { dimension in
                if let reference = capture.segments[dimension]?.centimeters,
                   let key = CoorditFitLabMeasurementKey(rawValue: dimension.measurementKey), let target = candidate?.measurements[key] {
                    Text("\(dimension.title) · 내 옷 \(String(format: "%.1f", reference)) → 상품 \(String(format: "%.1f", target)) cm (\(String(format: "%+.1f", target - reference)))")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(12), relativeTo: .body))
                        .accessibilityIdentifier("camera-fit-diff-\(dimension.rawValue)")
                }
            }
        }
    }

    private func actionButton(_ metrics: CoorditResponsiveMetrics) -> some View {
        Button {
            if isUnlocked { dismiss(); return }
            guard !isAnalyzing else { return }
            Task {
                isAnalyzing = true; failureMessage = nil
                defer { isAnalyzing = false }
                do {
                    capture.basisConfirmed = true
                    try await analyze(capture.makeMeasurement())
                    if savesReferenceOnly { dismiss() }
                }
                catch { failureMessage = error.localizedDescription }
            }
        } label: {
            HStack {
                if isAnalyzing { ProgressView().tint(.white) }
                Text(isUnlocked ? "상세 리포트 보기" : (isAnalyzing ? "준비 중" : (savesReferenceOnly ? "확인하고 저장" : (coordinator.cameraBundleAnalysisID == nil ? "확인하고 비교 · 실타래 1개" : "다시 비교 · 추가 차감 없음"))))
            }
        }
        .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
        .disabled(isAnalyzing || capture.isDetecting || (!isUnlocked && !capture.canReview))
        .accessibilityIdentifier("camera-fit-analyze")
    }

    @ViewBuilder private func bottomAction(_ metrics: CoorditResponsiveMetrics) -> some View {
        #if DEBUG
        if let fieldTestSession {
            CoorditARFieldTestControls(capture: capture, session: fieldTestSession)
        } else { actionButton(metrics) }
        #else
        actionButton(metrics)
        #endif
    }

    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined { cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video) }
        else { cameraAuthorized = status == .authorized }
        if !cameraAuthorized { failureMessage = "설정에서 카메라 권한을 허용하거나 카드 사진을 선택해주세요." }
    }
}
#endif
