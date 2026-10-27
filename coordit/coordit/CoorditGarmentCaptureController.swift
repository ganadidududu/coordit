#if os(iOS)
import ARKit
import AVFoundation
import Combine
import SceneKit
import SwiftUI
import UIKit


@MainActor
final class CoorditGarmentCaptureController: ObservableObject {
    enum Selection { case automatic, card, garment, manual }
    @Published private(set) var selection: Selection = .automatic
    @Published private(set) var method: CoorditGarmentMeasurement.Method
    @Published private(set) var image: UIImage?
    private(set) var garmentPhotoData: Data?
    @Published private(set) var corners: [CoorditMeasurementPoint] = []
    @Published private(set) var points: [CoorditMeasurementVector] = []
    @Published private(set) var projectedPoints: [CoorditMeasurementPoint] = []
    @Published private(set) var trackingReady = false
    @Published var message: String?
    @Published var lengthBasis = "high_shoulder_to_hem"
    @Published var basisConfirmed = false
    @Published private(set) var isDetecting = false
    @Published private(set) var outline: [CoorditMeasurementPoint] = []
    @Published private(set) var category: CoorditFitLabCategory = .tshirt
    @Published var longSleeves = false
    var isLower: Bool { category.garmentKind == .lower }
    @Published private(set) var hasAutomaticProposal = false
    private var detectionTask: Task<Void, Never>?
    private var detectionRevision = UUID()
    private var proposedEndpoints: [CoorditMeasurementPoint] = []
    var dimensions: [CoorditGarmentDimension] { category.cameraDimensions }
    private(set) var calibration: CoorditCardCalibration?
    private weak var sceneView: ARSCNView?
    private var lastProjectionTime: TimeInterval = 0
    private var measurementID = UUID()
    var identifier: UUID { measurementID }

    static var supportsLiDAR: Bool {
        ARWorldTrackingConfiguration.isSupported && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    static var featureEnabled: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.object(forInfoDictionaryKey: "CoorditCameraComparisonEnabled") as? Bool == true
        #endif
    }

    init(method: CoorditGarmentMeasurement.Method? = nil) {
        self.method = method ?? (Self.supportsLiDAR ? .lidar : .card)
    }

    var isComplete: Bool { points.count == dimensions.count * 2 }
    var dimension: CoorditGarmentDimension? {
        guard !isComplete else { return nil }
        return dimensions[points.count / 2]
    }
    var needsCardCorners: Bool { method == .card && image != nil && calibration == nil }
    var canReview: Bool {
        isComplete && (method == .card || trackingReady)
            && (try? CoorditGarmentMeasurement(method: method, segments: segments, lengthBasis: lengthBasis, category: category)) != nil
    }
    var canFinish: Bool { canReview && basisConfirmed }

    var instruction: String {
        if isDetecting { return "옷과 카드를 찾고 있어요" }
        if method == .card, selection != .manual {
            if selection == .card || needsCardCorners { return "사진에서 카드를 눌러주세요. 모서리는 끌어서 맞출 수 있어요." }
            if selection == .garment || !isComplete { return "사진에서 옷을 눌러주세요." }
        }
        if needsCardCorners {
            return "카드 모서리를 시계 방향으로 눌러주세요. \(corners.count + 1)/4"
        }
        if isComplete { return "점이 옷 끝에 맞는지 확인해주세요. 끌어서 조정할 수 있어요." }
        return dimension?.instruction ?? "옷을 평평하게 펴주세요."
    }

    func selectMethod(_ method: CoorditGarmentMeasurement.Method) {
        guard method != self.method else { return }
        self.method = method
        reset()
        image = nil
        sceneView?.session.pause()
    }

    func setImage(_ input: UIImage, detect: Bool = true) {
        selectMethod(.card)
        let maximum: CGFloat = 2400
        let ratio = min(1, maximum / max(input.size.width, input.size.height))
        let size = CGSize(width: input.size.width * ratio, height: input.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        image = UIGraphicsImageRenderer(size: size, format: format).image { _ in input.draw(in: CGRect(origin: .zero, size: size)) }
        reset()
        if detect { detectOutline() }
    }

    func configure(category: CoorditFitLabCategory) {
        guard self.category != category else { return }
        self.category = category
        longSleeves = category.garmentKind == .upper && category != .tshirt
        clearCapture()
        lengthBasis = isLower ? "waist_to_hem" : "high_shoulder_to_hem"
    }

    func select(_ target: Selection) {
        guard !isDetecting else { return }
        selection = target
        message = nil
    }

    func tapImage(_ point: CoorditMeasurementPoint) {
        guard point.isNormalized, !isDetecting else { return }
        if selection == .manual { addImagePoint(point); return }
        if selection == .card || needsCardCorners { detectOutline(cardHint: point) }
        else if selection == .garment || !isComplete { detectOutline(garmentHint: point) }
        else if CoorditGarmentOutlineDetector.contains(point, in: corners) { detectOutline(cardHint: point) }
        else if CoorditGarmentOutlineDetector.contains(point, in: outline) { detectOutline(garmentHint: point) }
    }

    func beginManualCard() {
        selection = .manual
        if !points.isEmpty { proposedEndpoints = points.compactMap { project($0) } }
        points = []; projectedPoints = []; corners = []; calibration = nil
        basisConfirmed = false; message = nil
    }

    func beginManualGarment() {
        selection = .manual
        points = []; projectedPoints = []; proposedEndpoints = []; outline = []
        hasAutomaticProposal = false; basisConfirmed = false; message = nil
    }

    func detectOutline(cardHint: CoorditMeasurementPoint? = nil, garmentHint: CoorditMeasurementPoint? = nil) {
        guard let data = image?.pngData(), method == .card else { return }
        detectionTask?.cancel()
        detectionRevision = UUID()
        let generation = detectionRevision
        isDetecting = true
        detectionTask = Task {
            defer { if generation == detectionRevision { isDetecting = false } }
            do {
                let proposal = try await CoorditGarmentOutlineDetector().detect(data, category: category, cardHint: cardHint, garmentHint: garmentHint)
                guard !Task.isCancelled, generation == detectionRevision else { return }
                guard proposal.endpoints.isEmpty || proposal.isLower == isLower else {
                    message = isLower ? "비교할 바지를 촬영해주세요." : "비교할 상의를 촬영해주세요."
                    return
                }
                message = nil
                if cardHint != nil {
                    guard proposal.corners.count == 4 else {
                        message = "카드 테두리를 찾지 못했어요. 확대해서 다시 누르거나 직접 맞춰주세요."
                        return
                    }
                    try replaceCard(proposal.corners)
                } else if garmentHint != nil {
                    guard !proposal.endpoints.isEmpty else {
                        message = "옷의 측정점을 찾지 못했어요. 다시 누르거나 직접 맞춰주세요."
                        return
                    }
                    outline = proposal.outline
                    proposedEndpoints = proposal.endpoints
                    points = []; projectedPoints = []
                } else {
                    outline = proposal.outline
                    proposedEndpoints = proposal.endpoints
                    for corner in proposal.corners { addImagePoint(corner) }
                }
                applyProposedEndpoints()
                selection = cardHint == nil ? .automatic : .card
                basisConfirmed = false
                validateEditedMeasurements()
            } catch {
                guard !Task.isCancelled, generation == detectionRevision else { return }
                message = "자동으로 찾지 못했어요. 카드나 옷을 눌러 다시 찾아주세요."
            }
        }
    }

    private func replaceCard(_ newCorners: [CoorditMeasurementPoint]) throws {
        guard let image else { return }
        let replacement = try CoorditCardCalibration(corners: newCorners, imageWidth: image.size.width, imageHeight: image.size.height)
        let imagePoints = points.compactMap { project($0) }
        let replacementPoints = try imagePoints.map(replacement.worldPoint)
        corners = newCorners
        calibration = replacement
        points = replacementPoints
        basisConfirmed = false
        refreshProjection()
    }

    func moveCardCorner(_ index: Int, to point: CoorditMeasurementPoint) {
        guard corners.indices.contains(index), point.isNormalized, !isDetecting else { return }
        var adjusted = corners
        adjusted[index] = point
        do {
            try replaceCard(adjusted)
            message = nil
            applyProposedEndpoints()
            validateEditedMeasurements()
        } catch { message = "카드의 네 모서리에 맞춰주세요." }
    }

    private func applyProposedEndpoints() {
        guard calibration != nil, points.isEmpty, proposedEndpoints.count == dimensions.count * 2 else { return }
        do {
            guard let calibration else { return }
            let values = try proposedEndpoints.map(calibration.worldPoint)
            let proposed = Dictionary(uniqueKeysWithValues: dimensions.enumerated().map { index, dimension in
                (dimension, CoorditMeasurementSegment(start: values[index * 2], end: values[index * 2 + 1]))
            })
            _ = try CoorditGarmentMeasurement(method: .card, segments: proposed, lengthBasis: lengthBasis, category: category)
            points = values
            hasAutomaticProposal = true
            refreshProjection()
        } catch { message = "\(error.localizedDescription) 옷의 끝점을 눌러주세요." }
    }

    func moveEndpoint(_ index: Int, to point: CoorditMeasurementPoint) {
        guard method == .card, points.indices.contains(index), let calibration, point.isNormalized,
              let world = try? calibration.worldPoint(point) else { return }
        points[index] = world
        basisConfirmed = false
        refreshProjection()
        validateEditedMeasurements()
    }

    private func validateEditedMeasurements() {
        guard isComplete else { return }
        do {
            _ = try CoorditGarmentMeasurement(method: method, segments: segments, lengthBasis: lengthBasis, category: category)
            message = nil
        } catch { message = error.localizedDescription }
    }

    func clearCapture() {
        image = nil
        reset()
        stop()
    }

    func reset() {
        garmentPhotoData = nil
        detectionTask?.cancel(); isDetecting = false; detectionRevision = UUID()
        selection = .automatic
        proposedEndpoints = []; outline = []; hasAutomaticProposal = false
        corners = []; points = []; projectedPoints = []; calibration = nil
        basisConfirmed = false; measurementID = UUID(); message = nil
    }

    func undo() {
        message = nil
        if !points.isEmpty { points.removeLast(); refreshProjection(); return }
        if !corners.isEmpty { calibration = nil; corners.removeLast() }
    }

    func addImagePoint(_ point: CoorditMeasurementPoint) {
        guard point.isNormalized, !isComplete, let image else { return }
        do {
            if needsCardCorners {
                corners.append(point)
                if corners.count == 4 {
                    do {
                        var ordered = corners
                        if selection == .manual {
                            func edge(_ first: Int, _ second: Int) -> Double {
                                hypot((corners[first].x - corners[second].x) * image.size.width,
                                      (corners[first].y - corners[second].y) * image.size.height)
                            }
                            if edge(1, 2) + edge(3, 0) > edge(0, 1) + edge(2, 3) {
                                ordered = [corners[1], corners[2], corners[3], corners[0]]
                            }
                        }
                        calibration = try CoorditCardCalibration(corners: ordered, imageWidth: image.size.width, imageHeight: image.size.height)
                        corners = ordered
                    }
                    catch { corners.removeLast(); throw error }
                    applyProposedEndpoints()
                }
            } else if let calibration {
                try append(try calibration.worldPoint(point))
            }
            message = nil
        } catch { message = error.localizedDescription }
    }

    func attach(_ view: ARSCNView) {
        sceneView = view
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.frameSemantics = [.sceneDepth]
        view.session.run(configuration)
    }

    func detectLiDAROutline() {
        guard !isDetecting, trackingReady, let view = sceneView,
              let originalFrame = view.session.currentFrame,
              let data = view.snapshot().pngData() else { return }
        reset()
        isDetecting = true
        let generation = measurementID
        let transform = originalFrame.camera.transform
        let viewport = view.bounds.size
        detectionTask = Task {
            defer { if generation == measurementID { isDetecting = false } }
            do {
                let proposal = try await CoorditGarmentOutlineDetector().detect(data, category: category)
                guard !Task.isCancelled, generation == measurementID,
                      let current = view.session.currentFrame else { return }
                guard trackingReady,
                      simd_distance(transform.columns.3, current.camera.transform.columns.3) < 0.015,
                      simd_dot(transform.columns.2, current.camera.transform.columns.2) > 0.999 else {
                    message = "잠시 카메라를 고정하고 다시 눌러주세요."
                    return
                }
                guard proposal.endpoints.count == dimensions.count * 2, proposal.isLower == isLower else {
                    message = "옷을 찾지 못했어요. 끝점을 눌러서 지정할 수 있어요."
                    return
                }
                for point in proposal.endpoints {
                    addLiDARPoint(at: .init(x: point.x * viewport.width, y: point.y * viewport.height))
                    if message != nil { points = []; refreshProjection(); return }
                }
                hasAutomaticProposal = isComplete
            } catch {
                guard generation == measurementID else { return }
                message = "자동으로 찾지 못했어요. 옷의 끝점을 눌러주세요."
            }
        }
    }

    func addLiDARPoint(at location: CGPoint) {
        guard !isComplete else { return }
        guard trackingReady, let view = sceneView, let frame = view.session.currentFrame,
              hasReliableDepth(at: location, frame: frame, viewport: view.bounds.size),
              let query = view.raycastQuery(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal),
              let result = view.session.raycast(query).first else {
            message = CoorditGarmentMeasurementError.unstableTracking.errorDescription
            return
        }
        let position = result.worldTransform.columns.3
        if let first = points.first, abs(Double(position.y) - first.y) > 0.025 {
            message = "모든 측정점은 같은 평면 위에 있어야 해요. 옷을 평평하게 펴주세요."
            return
        }
        do {
            try append(.init(x: Double(position.x), y: points.first?.y ?? Double(position.y), z: Double(position.z)))
            message = nil
        } catch { message = error.localizedDescription }
    }

    private func hasReliableDepth(at location: CGPoint, frame: ARFrame, viewport: CGSize) -> Bool {
        guard viewport.width > 0, viewport.height > 0, let depth = frame.sceneDepth,
              let confidence = depth.confidenceMap else { return false }
        let orientation = sceneView?.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let normalized = CGPoint(x: location.x / viewport.width, y: location.y / viewport.height)
            .applying(frame.displayTransform(for: orientation, viewportSize: viewport).inverted())
        guard (0...1).contains(normalized.x), (0...1).contains(normalized.y) else { return false }
        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(confidence) else { return false }
        let x = min(CVPixelBufferGetWidth(confidence) - 1, Int(normalized.x * CGFloat(CVPixelBufferGetWidth(confidence))))
        let y = min(CVPixelBufferGetHeight(confidence) - 1, Int(normalized.y * CGFloat(CVPixelBufferGetHeight(confidence))))
        return Int(base.assumingMemoryBound(to: UInt8.self)[y * CVPixelBufferGetBytesPerRow(confidence) + x]) >= ARConfidenceLevel.medium.rawValue
    }

    private func append(_ point: CoorditMeasurementVector) throws {
        guard point.isFinite, let dimension else { throw CoorditGarmentMeasurementError.invalidPoint }
        if points.count % 2 == 1, let first = points.last {
            let segment = CoorditMeasurementSegment(start: first, end: point)
            guard dimension.validRange.contains(segment.centimeters) else { throw CoorditGarmentMeasurementError.invalidDimension(dimension.title) }
        }
        points.append(point)
        refreshProjection()
    }

    func makeMeasurement() throws -> CoorditGarmentMeasurement {
        guard canFinish else { throw CoorditGarmentMeasurementError.unstableTracking }
        let measurement = try CoorditGarmentMeasurement(id: measurementID, method: method, segments: segments, lengthBasis: lengthBasis, category: category)
        if let photo = method == .card ? image : sceneView?.snapshot() {
            let scale = min(1, 1200 / max(photo.size.width, photo.size.height))
            let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            garmentPhotoData = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                photo.draw(in: CGRect(origin: .zero, size: size))
            }.jpegData(compressionQuality: 0.85)
        }
        return measurement
    }

    var segments: [CoorditGarmentDimension: CoorditMeasurementSegment] {
        Dictionary(uniqueKeysWithValues: dimensions.enumerated().compactMap { index, dimension in
            guard points.count > index * 2 + 1 else { return nil }
            return (dimension, .init(start: points[index * 2], end: points[index * 2 + 1]))
        })
    }

    func project(_ point: CoorditMeasurementVector) -> CoorditMeasurementPoint? {
        if method == .card { return calibration?.imagePoint(point) }
        guard trackingReady, let view = sceneView, view.bounds.width > 0, view.bounds.height > 0 else { return nil }
        let projected = view.projectPoint(SCNVector3(point.simd))
        guard projected.z > 0, projected.z < 1 else { return nil }
        return .init(x: Double(CGFloat(projected.x) / view.bounds.width), y: Double(CGFloat(projected.y) / view.bounds.height))
    }

    func updateTracking() {
        guard method == .lidar, let frame = sceneView?.session.currentFrame else { return }
        let time = Date.timeIntervalSinceReferenceDate
        guard time - lastProjectionTime >= 0.1 else { return }
        lastProjectionTime = time
        let ready: Bool
        if case .normal = frame.camera.trackingState {
            ready = frame.sceneDepth != nil && abs(frame.camera.transform.columns.2.y) > 0.75
        } else { ready = false }
        if trackingReady != ready { trackingReady = ready }
        refreshProjection()
    }

    private func refreshProjection() {
        projectedPoints = points.compactMap(project)
    }

    func stop() { sceneView?.session.pause(); trackingReady = false }
    func resume() { if let sceneView, method == .lidar { attach(sceneView) } }

    #if DEBUG
    func loadGuideTestFixture() {
        selectMethod(.card)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let fixture = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 3000), format: format).image { context in
            UIColor(white: 0.92, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 3000))
            UIColor(white: 0.15, alpha: 1).setFill()
            context.cgContext.addPath(CoorditGarmentGuideShape(category: category, longSleeves: longSleeves).path(in: CGRect(x: 150, y: 100, width: 2100, height: 2300)).cgPath)
            context.cgContext.fillPath()
            UIColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: 180, y: 2650, width: 240, height: 240 * 53.98 / 85.60), cornerRadius: 8).fill()
            if ProcessInfo.processInfo.arguments.contains("--coordit-test-ambiguous-card") {
                UIBezierPath(roundedRect: CGRect(x: 1900, y: 2650, width: 240, height: 240 * 53.98 / 85.60), cornerRadius: 8).fill()
            }
        }
        setImage(fixture)
    }

    func loadTestFixture(automatic: Bool = false) {
        selectMethod(.card)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1500))
        let fixtureImage = renderer.image { context in
            UIColor(CoorditDesignTokens.ColorToken.field).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1500))
            UIColor.white.setFill()
            let shirt = UIBezierPath()
            shirt.move(to: CGPoint(x: 250, y: 240)); shirt.addLine(to: CGPoint(x: 420, y: 180))
            shirt.addQuadCurve(to: CGPoint(x: 780, y: 180), controlPoint: CGPoint(x: 600, y: 350))
            shirt.addLine(to: CGPoint(x: 950, y: 240)); shirt.addLine(to: CGPoint(x: 1090, y: 430))
            shirt.addLine(to: CGPoint(x: 910, y: 540)); shirt.addLine(to: CGPoint(x: 870, y: 460))
            shirt.addLine(to: CGPoint(x: 870, y: 1210)); shirt.addLine(to: CGPoint(x: 330, y: 1210))
            shirt.addLine(to: CGPoint(x: 330, y: 460)); shirt.addLine(to: CGPoint(x: 290, y: 540))
            shirt.addLine(to: CGPoint(x: 110, y: 430)); shirt.close(); shirt.fill()
            UIColor(CoorditDesignTokens.ColorToken.ink).setFill()
            UIBezierPath(roundedRect: CGRect(x: 60, y: 1280, width: 171.2, height: 107.96), cornerRadius: 8).fill()
        }
        setImage(fixtureImage, detect: automatic)
        if automatic { return }
        let cardPixels: [(Double, Double)] = [(60, 1280), (231.2, 1280), (231.2, 1387.96), (60, 1387.96)]
        let card = cardPixels.map { CoorditMeasurementPoint(x: $0.0 / 1200.0, y: $0.1 / 1500.0) }
        card.forEach(addImagePoint)
        let endpoints: [(Double, Double)] = [(250, 240), (950, 240), (330, 460), (870, 460), (420, 180), (420, 1210), (950, 240), (1090, 430)]
        endpoints.forEach { addImagePoint(.init(x: $0.0 / 1200, y: $0.1 / 1500)) }
        basisConfirmed = true
    }
    #endif
}
struct CoorditLiDARCameraView: UIViewRepresentable {
    @ObservedObject var controller: CoorditGarmentCaptureController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.scene = SCNScene()
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = false
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        controller.attach(view)
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) { uiView.session.pause() }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        let controller: CoorditGarmentCaptureController
        init(controller: CoorditGarmentCaptureController) { self.controller = controller }
        @objc func tap(_ gesture: UITapGestureRecognizer) { controller.addLiDARPoint(at: gesture.location(in: gesture.view)) }
        nonisolated func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            Task { @MainActor [weak self] in self?.controller.updateTracking() }
        }
    }
}
#endif
