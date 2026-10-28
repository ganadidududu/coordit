#if os(iOS) && DEBUG
import SwiftUI
import UniformTypeIdentifiers

struct CoorditARFieldTestScreen: View {
    @StateObject private var session = CoorditARFieldTestSession()
    @StateObject private var capture = CoorditGarmentCaptureController(method: .arPlane)
    @StateObject private var coordinator = CoorditFitLabCoordinator(route: .fitLabInput, configuration: .production)

    var body: some View {
        #if targetEnvironment(simulator)
        if CoorditHostedARFixture.enabled { CoorditHostedARFixture.screen }
        else { cameraScreen }
        #else
        cameraScreen
        #endif
    }

    private var cameraScreen: some View {
        CoorditFitLabCameraComparison(coordinator: coordinator, analyze: { _ in }, capture: capture, fieldTestSession: session)
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("AR 실기기 시험 · 결제/저장 없음").font(.caption.bold())
                        .accessibilityIdentifier("ar-field-screen")
                    Spacer()
                    Picker("종류", selection: Binding(get: { capture.category }, set: { capture.configure(category: $0) })) {
                        ForEach(CoorditFitLabCategory.allCases) { Text($0.koreanTitle).tag($0) }
                    }
                    .disabled(capture.image != nil)
                    .accessibilityIdentifier("ar-field-category")
                }
                .padding(.horizontal).padding(.vertical, 4)
                .background(CoorditFitLabPalette.surface)
            }
    }
}

struct CoorditFieldJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CoorditARFieldTestControls: View {
    @ObservedObject var capture: CoorditGarmentCaptureController
    @ObservedObject var session: CoorditARFieldTestSession
    @State private var showsSettings = false
    @State private var showsExport = false
    @State private var document: CoorditFieldJSONDocument?
    @State private var showsHostedAR = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Astra / Gemini 봉제점 · AR cm") {
                capture.cancelInference()
                showsHostedAR = true
            }
            .disabled(!capture.isFrozenAR)
            .accessibilityIdentifier("ar-field-hosted-ai")
            HStack {
                Button { showsSettings = true } label: {
                    Text(session.garmentID.isEmpty ? "시험 정보 입력" : session.garmentID).frame(minHeight: 44)
                }
                    .accessibilityIdentifier("ar-field-settings")
                Spacer()
                Button {
                    do { document = try .init(data: session.encoded()); showsExport = true }
                    catch { session.notice = error.localizedDescription }
                } label: { Text("내보내기 \(session.trials.count)").frame(minHeight: 44) }
                .disabled(session.trials.isEmpty)
                .accessibilityIdentifier("ar-field-export")
                .accessibilityValue(String(session.trials.count))
            }
            HStack {
                Button("자동점 / 실패 기록") { record("automatic") }
                    .disabled(capture.isDetecting || session.hasAutomatic(capture))
                    .accessibilityIdentifier("ar-field-automatic")
                Button("보정 / 실패 기록") { record("manual") }
                    .disabled(capture.isDetecting || !session.hasAutomatic(capture))
                    .accessibilityIdentifier("ar-field-manual")
                Button("다음 시도") { capture.clearCapture() }
                    .disabled(capture.isDetecting)
                    .accessibilityIdentifier("ar-field-next")
            }
            .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary, height: 44, fontSize: 11))
            Text(session.notice ?? "자동 결과를 먼저 기록하고 점을 보정하세요. 원본 사진은 내보내지 않아요.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ar-field-notice")
            if let evidence = capture.measurementEvidence {
                Text("프레임 \(evidence.frameID.uuidString.prefix(8)) · 평면 \(evidence.stablePlaneSeconds, specifier: "%.1f")초 · 이동 \(evidence.cameraMotionBaselineMeters * 100, specifier: "%.1f")cm")
                    .font(.caption2).accessibilityIdentifier("ar-field-evidence")
            }
        }
        .font(.caption)
        .onChange(of: capture.isDetecting) { _, _ in session.prepareAutomatic(capture) }
        .onChange(of: capture.image) { _, _ in session.prepareAutomatic(capture) }
        .sheet(isPresented: $showsSettings) { settings }
        .sheet(isPresented: $showsHostedAR) {
            if let snapshot = capture.hostedARSnapshot {
                CoorditHostedARReview(snapshot: snapshot, category: capture.category,
                    garmentID: session.garmentID, groundTruth: session.groundTruth, lengthBasis: capture.lengthBasis)
            }
        }
        .fileExporter(isPresented: $showsExport, document: document, contentType: .json,
            defaultFilename: "coordit-ar-\(UUID().uuidString.prefix(8))") { result in
                switch result {
                case .success: session.notice = "파일 저장 완료 · 앱 종료 전 최신 결과를 다시 내보내세요."
                case .failure(let error): session.notice = error.localizedDescription
                }
            }
    }

    private func record(_ stage: String) {
        do { try session.record(capture, stage: stage) }
        catch { session.notice = error.localizedDescription }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("같은 실물에는 같은 ID") {
                    TextField("예: my-tshirt-01", text: $session.garmentID).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().accessibilityIdentifier("ar-field-garment-id")
                    TextField("배경 · 예: 나무 바닥", text: $session.background).accessibilityIdentifier("ar-field-background")
                    TextField("조명 · 예: 밝은 실내", text: $session.lighting).accessibilityIdentifier("ar-field-lighting")
                }
                Section("줄자 정답 · cm · 둘레가 아닌 단면") {
                    ForEach(capture.dimensions) { dimension in
                        HStack {
                            Text(dimension.title)
                            TextField("cm", text: Binding(get: { session.groundTruth[dimension.measurementKey] ?? "" },
                                set: { session.groundTruth[dimension.measurementKey] = $0 }))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("ar-field-truth-\(dimension.measurementKey)")
                        }
                    }
                    Text("총장 기준: \(capture.lengthBasis). 사진 속 점과 줄자의 시작·끝을 일치시키세요.")
                    Toggle("학습에 사용하지 않은 독립 평가용 의류예요", isOn: $session.independent)
                        .accessibilityIdentifier("ar-field-independent")
                }
                Section {
                    Text("현재 자동점은 윤곽 휴리스틱이며 실제 봉제선 AI 정확도는 미검증입니다. 원본 사진·학습 동의는 수집하지 않아요. 결과는 앱 메모리에 있으므로 종료 전 파일로 내보내세요. 시뮬레이터 결과는 synthetic으로 표시되어 실제 정확도 평가에서 거부됩니다.")
                }
            }
            .navigationTitle("AR 시험 정보")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showsSettings = false } } }
        }
    }
}
#endif
