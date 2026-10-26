#if os(iOS)
import SwiftUI

struct CoorditClosetCameraRegistration: View {
    @Binding var draft: CoorditClosetDraft
    let metrics: CoorditResponsiveMetrics
    let onBack: () -> Void
    let onSubmit: () -> Void
    @StateObject private var coordinator = CoorditFitLabCoordinator(route: .fitLabInput, configuration: .production)
    @State private var showsCapture = false

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.value(20)) {
            CoorditClosetTitleBar(title: "CAMERA FIT", metrics: metrics, onBack: onBack)
            Text("어떤 옷을 촬영할까요?")
                .font(CoorditTypography.gmarketBold(size: metrics.value(20)))
            ForEach([CoorditFitLabCategory.tshirt, .pants], id: \.self) { category in
                Button(category == .tshirt ? "반팔 티셔츠" : "바지") {
                    draft.exactCategory = category
                    draft.category = category == .tshirt ? .top : .bottom
                    coordinator.cameraCapture.configure(isLower: category == .pants)
                    showsCapture = true
                }
                .buttonStyle(CoorditContentActionButtonStyle(prominence: .secondary))
            }
            Spacer()
        }
        .padding(.horizontal, metrics.value(22))
        .fullScreenCover(isPresented: $showsCapture) {
            CoorditFitLabCameraComparison(coordinator: coordinator, analyze: { measurement in
                draft.method = .photo
                draft.name = measurement.isLower ? "잘 맞는 바지" : "잘 맞는 티셔츠"
                let values = measurement.dimensions.compactMap { measurement.measurementValues[$0.measurementKey] }
                guard values.count == 4 else { throw CoorditGarmentMeasurementError.invalidPoint }
                draft.measurement1 = String(values[0]); draft.measurement2 = String(values[1])
                draft.measurement3 = String(values[2]); draft.measurement4 = String(values[3])
                draft.cameraMeasurement = measurement
                draft.garmentImageData = coordinator.cameraCapture.garmentPhotoData
                showsCapture = false
                onSubmit()
            }, capture: coordinator.cameraCapture, savesReferenceOnly: true)
        }
    }
}
#endif
