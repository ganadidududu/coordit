#if os(iOS)
import SwiftUI
import CoreMotion
import Combine

extension CoorditFitLabCategory {
    nonisolated var cameraDimensions: [CoorditGarmentDimension] {
        if self == .skirt { return [.waist, .hip, .length] }
        return garmentKind == .lower ? CoorditGarmentDimension.lower : CoorditGarmentDimension.upper
    }

    var captureInstruction: String {
        switch self {
        case .hoodie: "후드를 위로 펴고 소매를 벌려주세요"
        case .jacket, .coat: "앞을 잠그고 소매를 벌려주세요"
        case .pants, .jeans, .shorts: "허리를 위로, 두 다리를 살짝 벌려주세요"
        case .skirt: "허리를 위로 두고 밑단을 펴주세요"
        default: "목을 위로 두고 소매를 벌려주세요"
        }
    }
}

#if DEBUG
struct CoorditGarmentGuideShape: Shape {
    let category: CoorditFitLabCategory
    var longSleeves = false

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint]
        switch category {
        case .pants, .jeans:
            points = [.init(x: 0.25, y: 0.04), .init(x: 0.75, y: 0.04), .init(x: 0.80, y: 0.23), .init(x: 0.78, y: 0.96), .init(x: 0.55, y: 0.96), .init(x: 0.50, y: 0.37), .init(x: 0.45, y: 0.96), .init(x: 0.22, y: 0.96), .init(x: 0.20, y: 0.23)]
        case .shorts:
            points = [.init(x: 0.25, y: 0.16), .init(x: 0.75, y: 0.16), .init(x: 0.82, y: 0.40), .init(x: 0.86, y: 0.80), .init(x: 0.54, y: 0.80), .init(x: 0.50, y: 0.53), .init(x: 0.46, y: 0.80), .init(x: 0.14, y: 0.80), .init(x: 0.18, y: 0.40)]
        case .skirt:
            points = [.init(x: 0.30, y: 0.10), .init(x: 0.70, y: 0.10), .init(x: 0.88, y: 0.90), .init(x: 0.12, y: 0.90)]
        default:
            let short = category == .tshirt && !longSleeves
            let hem = category == .coat ? 0.98 : 0.88
            var upper: [CGPoint] = [.init(x: 0.27, y: 0.23), .init(x: 0.39, y: 0.17)]
            if category == .hoodie {
                upper += [.init(x: 0.40, y: 0.06), .init(x: 0.45, y: 0.01), .init(x: 0.55, y: 0.01), .init(x: 0.60, y: 0.06), .init(x: 0.61, y: 0.17)]
            } else {
                upper += [.init(x: 0.44, y: 0.23), .init(x: 0.56, y: 0.23), .init(x: 0.61, y: 0.17)]
            }
            upper += [.init(x: 0.73, y: 0.23), .init(x: 0.97, y: short ? 0.38 : 0.63), .init(x: 0.83, y: short ? 0.47 : 0.71), .init(x: 0.73, y: 0.40), .init(x: 0.73, y: hem), .init(x: 0.27, y: hem), .init(x: 0.27, y: 0.40), .init(x: 0.17, y: short ? 0.47 : 0.71), .init(x: 0.03, y: short ? 0.38 : 0.63)]
            points = upper
        }
        return Path { path in
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
            path.closeSubpath()
        }
    }
}

#endif

enum CoorditCameraPosture: Equatable {
    case unavailable, tilted, moving, ready

    var text: String {
        switch self {
        case .unavailable: "옷과 카드가 모두 보이게 찍어주세요"
        case .tilted: "조금 더 수직으로 찍어주세요"
        case .moving: "잠깐, 카메라를 고정해주세요"
        case .ready: "좋아요. 이대로 찍어주세요"
        }
    }

    nonisolated static func evaluate(gravityZ: Double, rotation: Double, acceleration: Double) -> Self {
        // Rear camera faces the floor when the screen faces up (gravity.z approaches -1).
        if gravityZ > -cos(12 * .pi / 180) { return .tilted }
        if rotation > 0.18 || acceleration > 0.035 { return .moving }
        return .ready
    }
}

@MainActor
final class CoorditCameraMotion: ObservableObject {
    @Published private(set) var posture: CoorditCameraPosture = .unavailable
    private let manager = CMMotionManager()
    private var candidate: CoorditCameraPosture = .unavailable
    private var stableSamples = 0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let rotation = motion.rotationRate
            let acceleration = motion.userAcceleration
            let next = CoorditCameraPosture.evaluate(gravityZ: motion.gravity.z,
                rotation: sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z),
                acceleration: sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z))
            Task { @MainActor [weak self] in self?.update(next) }
        }
    }

    func update(_ next: CoorditCameraPosture) {
        stableSamples = candidate == next ? stableSamples + 1 : 1
        candidate = next
        if stableSamples >= 4 { posture = next }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        candidate = .unavailable
        stableSamples = 0
        posture = .unavailable
    }
}

struct CoorditGarmentCameraOverlay: View {
    let category: CoorditFitLabCategory
    let takePhoto: () -> Void
    let cancel: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var motion = CoorditCameraMotion()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(category.koreanTitle)
                    .font(CoorditTypography.gmarketBold(size: 18, relativeTo: .headline))
                Spacer()
                Button(action: cancel) {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("촬영 닫기")
            }
            .padding(.horizontal, 20)
            .background(.black.opacity(0.65))
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                Label(motion.posture.text, systemImage: motion.posture == .ready ? "checkmark.circle" : "camera.metering.center.weighted")
                    .font(CoorditTypography.gmarketMedium(size: 14, relativeTo: .body))
                    .accessibilityIdentifier("camera-fit-motion-hint")
                Text("옷과 카드를 같은 바닥에 놓아주세요")
                    .font(CoorditTypography.gmarketMedium(size: 12, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: takePhoto) {
                    Circle().fill(.white).padding(5)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 68, height: 68)
                }
                .accessibilityLabel("사진 촬영")
                .accessibilityIdentifier("camera-fit-shutter")
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.75))
        }
        .foregroundStyle(.white)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { motion.start() } else { motion.stop() }
        }
    }
}

struct CoorditGuidedGarmentCamera: UIViewControllerRepresentable {
    let category: CoorditFitLabCategory
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> CoorditFitLabCameraPicker.Coordinator {
        .init(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.showsCameraControls = false
        picker.delegate = context.coordinator
        let overlay = UIHostingController(rootView: CoorditGarmentCameraOverlay(category: category, takePhoto: { [weak picker] in
            picker?.takePicture()
        }, cancel: { completion(nil) }))
        picker.addChild(overlay)
        overlay.view.backgroundColor = .clear
        overlay.view.frame = picker.view.bounds
        overlay.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        picker.cameraOverlayView = overlay.view
        overlay.didMove(toParent: picker)
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
#endif
