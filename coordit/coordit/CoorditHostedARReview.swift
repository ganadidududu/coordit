#if os(iOS) && DEBUG
import SwiftUI
import UniformTypeIdentifiers

struct CoorditHostedARReview: View {
    let snapshot: CoorditARPlaneCapture
    let category: CoorditFitLabCategory
    let garmentID: String
    let lengthBasis: String
    let groundTruth: [String: String]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPoint = "shoulder_left"
    @State private var editingPoints = false
    @State private var xInput = ""
    @State private var yInput = ""
    @State private var model: CoorditHostedModel = .astra
    @State private var hasUnsavedResults: Bool
    @State private var showsDiscardConfirmation = false
    @State private var consent = false
    @State private var busy = false
    @State private var reply: CoorditHostedReply?
    @State private var history: [CoorditHostedReply]
    @State private var notice: String?
    @State private var job: Task<Void, Never>?
    @State private var showsExport = false
    @State private var document: CoorditFieldJSONDocument?

    init(snapshot: CoorditARPlaneCapture, category: CoorditFitLabCategory, garmentID: String = "",
         groundTruth: [String: String] = [:], lengthBasis: String = "high_shoulder_to_hem", initialReply: CoorditHostedReply? = nil) {
        self.snapshot = snapshot; self.category = category
        self.garmentID = garmentID; self.groundTruth = groundTruth
        self.lengthBasis = category.garmentKind == .lower ? "waist_to_hem" : lengthBasis
        _hasUnsavedResults = State(initialValue: initialReply != nil)
        _reply = State(initialValue: initialReply)
        _history = State(initialValue: initialReply.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    #if targetEnvironment(simulator)
                    Text("시뮬레이터 합성 시험 · 실제 cm 정확도 평가 불가").font(.subheadline).foregroundStyle(.primary)
                    #endif
                    Picker("봉제점 모델", selection: $model) {
                        ForEach(CoorditHostedModel.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).disabled(busy).accessibilityIdentifier("hosted-ar-model")
                    Text("\(category.koreanTitle) · 촬영 프레임 \(snapshot.evidence.frameID.uuidString.prefix(8))")
                        .font(.subheadline)
                    if let reply {
                        Menu {
                            ForEach(reply.points.points) { point in
                                Button("\(point.title) · \(point.usable ? "확인 필요" : "보정 필요")") {
                                    selectedPoint = point.id
                                }
                            }
                        } label: {
                            HStack {
                                Text("보정할 기준점: \(reply.points.points.first { $0.id == selectedPoint }?.title ?? "선택")")
                                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                            }.frame(minHeight: 44)
                        }.accessibilityIdentifier("hosted-ar-selected-point").disabled(busy)
                    }
                    if reply != nil {
                        Toggle("사진에서 점 보정", isOn: $editingPoints).disabled(busy)
                            .accessibilityIdentifier("hosted-ar-edit-points")
                    }
                    Text(lengthBasis == "high_shoulder_to_hem" ? "총장: 왼쪽 어깨–목 접점에서 옷 세로 방향으로 내려간 밑단" :
                        (lengthBasis == "back_neck_to_hem" ? "총장: 보이는 뒷목 중심부터 밑단 중심" : "총장: 허리 중심부터 스커트 밑단"))
                        .font(.subheadline)
                    photo
                    if reply != nil {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("가로 (%)").font(.subheadline)
                                TextField("0–100", text: $xInput).keyboardType(.decimalPad)
                                    .accessibilityLabel("선택한 기준점 가로 백분율")
                            }
                            VStack(alignment: .leading) {
                                Text("세로 (%)").font(.subheadline)
                                TextField("0–100", text: $yInput).keyboardType(.decimalPad)
                                    .accessibilityLabel("선택한 기준점 세로 백분율")
                            }
                            Button {
                                guard let x = Double(xInput), let y = Double(yInput) else { return }
                                move(selectedPoint, x: x / 100, y: y / 100)
                            } label: { Text("좌표 적용").frame(minHeight: 44) }
                        }.textFieldStyle(.roundedBorder).disabled(busy)
                    }
                    if let reply {
                        Text("\(reply.model) · \(reply.elapsedSeconds, specifier: "%.1f")초 · 비용 \(reply.costUsd.map { String(format: "$%.4f", $0) } ?? "미확인")")
                            .font(.subheadline).accessibilityIdentifier("hosted-ar-result")
                        ForEach(CoorditHostedSemantics.pairs(category), id: \.0) { pair in
                            HStack {
                                Text(pair.0.title)
                                Spacer()
                                if let segment = CoorditHostedSemantics.segment(pair, points: reply.points.points, geometry: snapshot.geometry) {
                                    Text("\(segment.centimeters, specifier: "%.1f") cm")
                                } else { Text("점 누락·불확실·평면 밖 · 보정 필요").foregroundStyle(.primary) }
                            }.font(.subheadline).accessibilityIdentifier("hosted-ar-cm-\(pair.0.rawValue)")
                        }
                        Text("기준점 선택 후 ‘사진에서 점 보정’을 켜고 터치·드래그하세요. 보정 후에는 꺼서 화면을 스크롤하세요. 주황점·빠진 점은 보정이 필요하며 초록점도 확인하세요. 총장은 위에 표시한 기준, 소매는 오른쪽 어깨–커프 기준입니다.")
                            .font(.subheadline)
                        Button { export() } label: { Text("AI·AR 결과 JSON 내보내기").frame(minHeight: 44) }
                            .disabled(busy).accessibilityIdentifier("hosted-ar-export")
                    }
                    Toggle("의류 사진을 개발 서버와 OpenRouter의 선택 모델 제공업체로 전송하는 데 동의해요", isOn: $consent)
                        .font(.subheadline).disabled(busy).accessibilityIdentifier("hosted-ar-consent")
                    Text("Cloudflare HTTPS 연결 · 위치정보 제거 · 서버 원본 보관·학습 없음 · 유료 API 호출 · 개발용, 정확도 미검증. Mac 개발 서버와 인터넷이 필요하며 전송 후 닫아도 API 비용이 발생할 수 있어요.")
                        .font(.subheadline).foregroundStyle(.primary)
                    Button(busy ? "봉제점 확인 중…" : "\(model.title)로 봉제점 찾기") { infer() }
                        .buttonStyle(.borderedProminent).disabled(!consent || busy || CoorditHostedARClient.configured == nil)
                        .accessibilityIdentifier("hosted-ar-infer")
                    if CoorditHostedARClient.configured == nil { Text("개발 서버 연결 설정이 없는 빌드입니다.").font(.subheadline) }
                    if let notice { Text(notice).font(.subheadline).accessibilityIdentifier("hosted-ar-notice") }
                }.padding()
            }.scrollDismissesKeyboard(.interactively)
            .navigationTitle("AI 봉제점 · AR 실측")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("닫기") { if hasUnsavedResults { showsDiscardConfirmation = true } else { dismiss() } }
            } }
            .interactiveDismissDisabled(hasUnsavedResults)
            .alert("내보내지 않은 시험 결과가 있어요", isPresented: $showsDiscardConfirmation) {
                Button("결과 버리고 닫기", role: .destructive) { dismiss() }
                Button("계속 확인", role: .cancel) { }
            } message: { Text("닫으면 이 화면의 AI 응답과 보정 결과가 사라져요. 먼저 JSON을 내보내세요.") }
            .onAppear { syncInputs() }
            .onChange(of: selectedPoint) { _, _ in syncInputs() }
            .onDisappear { job?.cancel() }
            .fileExporter(isPresented: $showsExport, document: document, contentType: .json,
                defaultFilename: "coordit-hosted-ar-\(snapshot.evidence.frameID.uuidString.prefix(8))") { result in
                    switch result {
                    case .success: hasUnsavedResults = false; notice = "JSON 저장 완료"
                    case .failure: notice = "내보내기를 완료하지 못했어요. 결과를 유지했어요. 다시 내보내세요."
                    }
                }
        }
    }

    private var photo: some View {
        GeometryReader { size in
            ZStack(alignment: .topLeading) {
                Image(uiImage: snapshot.image).resizable().scaledToFit()
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("hosted-ar-photo")
                    .accessibilityLabel("촬영 순간의 의류 사진, 선택한 기준점을 배치할 영역")
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("hosted-photo"))
                        .onChanged { value in
                            guard editingPoints && !busy else { return }
                            move(selectedPoint, x: value.location.x / size.size.width, y: value.location.y / size.size.height)
                        }, including: editingPoints && !busy ? .all : .none)
                if let reply {
                    ForEach(reply.points.points) { point in
                        if let position = point.position {
                            Circle().fill(point.usable ? Color.green : Color.orange).frame(width: 22, height: 22)
                                .overlay(Circle().stroke(point.id == selectedPoint ? .black : .white, lineWidth: 3))
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                                .accessibilityLabel(point.title)
                                .accessibilityValue(point.usable ? "확인 필요" : "보정 필요")
                                .position(x: position.x * size.size.width, y: position.y * size.size.height)
                                .accessibilityIdentifier("hosted-ar-point-\(point.id)")
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("hosted-photo"))
                                    .onChanged { value in
                                        selectedPoint = point.id
                                        move(point.id, x: value.location.x / size.size.width, y: value.location.y / size.size.height)
                                    })
                                .allowsHitTesting(editingPoints && !busy)
                        }
                    }
                }
            }.coordinateSpace(name: "hosted-photo")
        }.aspectRatio(snapshot.image.size.width / snapshot.image.size.height, contentMode: .fit)
    }

    private func syncInputs() {
        let point = reply?.points.points.first { $0.id == selectedPoint }
        xInput = point?.x.map { String(format: "%.2f", $0 * 100) } ?? ""
        yInput = point?.y.map { String(format: "%.2f", $0 * 100) } ?? ""
    }

    private func move(_ id: String, x: Double, y: Double) {
        guard let index = reply?.points.points.firstIndex(where: { $0.id == id }),
              (try? snapshot.geometry.worldPoint(.init(x: x, y: y))) != nil else { return }
        reply?.points.points[index].x = x; reply?.points.points[index].y = y
        reply?.points.points[index].status = "user_corrected"
        hasUnsavedResults = true
        syncInputs()
    }

    private func infer() {
        guard consent, let client = CoorditHostedARClient.configured, let image = snapshot.image.pngData() else { return }
        busy = true; notice = nil
        let selected = model
        job = Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await client.infer(image: image, frameID: snapshot.evidence.frameID, category: category, model: selected, lengthBasis: lengthBasis)
                try Task.checkCancellation()
                reply = result
                selectedPoint = result.points.points.first?.id ?? ""
                history.append(result)
                hasUnsavedResults = true
                notice = "촬영 당시 평면으로 계산했어요. 불확실한 점은 직접 보정해주세요."
            } catch {
                if !Task.isCancelled { notice = "서버 연결 또는 AI 추론에 실패했어요. 기존 측정 결과를 유지했어요." }
            }
        }
    }

    private func export() {
        guard let reply else { return }
        struct Measurement: Encodable {
            let dimension: String
            let centimeters: Double?
            let groundTruthCm: Double?
            let segment: CoorditMeasurementSegment?
            let failureReason: String?
        }
        struct Result: Encodable {
            let purpose = "hosted_ar_development_not_training"
            let garmentID: String
            let evidence: CoorditARMeasurementEvidence
            let originalInferences: [CoorditHostedReply]
            let correctedInference: CoorditHostedReply
            let measurements: [Measurement]
            #if targetEnvironment(simulator)
            let synthetic = true
            #else
            let synthetic = false
            #endif
        }
        let pairs = CoorditHostedSemantics.pairs(category)
        let measurements = pairs.map { pair in
            let segment = CoorditHostedSemantics.segment(pair, points: reply.points.points, geometry: snapshot.geometry)
            return Measurement(dimension: pair.0.measurementKey, centimeters: segment?.centimeters,
                groundTruthCm: Double(groundTruth[pair.0.measurementKey] ?? ""), segment: segment,
                failureReason: segment == nil ? "missing_uncertain_outside_plane_or_invalid_range" : nil)
        }
        var evidence = snapshot.evidence
        evidence.corrected = reply.points.points.contains { $0.status == "user_corrected" }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.keyEncodingStrategy = .convertToSnakeCase
            document = .init(data: try encoder.encode(Result(garmentID: garmentID, evidence: evidence,
                originalInferences: history, correctedInference: reply, measurements: measurements)))
            showsExport = true
        } catch { notice = "내보내기에 실패했어요." }
    }
}
#endif
