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
            CoorditGarmentCategorySelector(kind: Binding(get: { draft.exactCategory.garmentKind }, set: { kind in
                draft.category = kind == .upper ? .top : .bottom
                draft.exactCategory = kind == .upper ? .tshirt : .pants
            }), category: $draft.exactCategory, metrics: metrics, identifier: "closet-camera")
            Button("계속") {
                draft.category = draft.exactCategory.garmentKind == .upper ? .top : .bottom
                coordinator.cameraCapture.configure(category: draft.exactCategory)
                showsCapture = true
            }
            .buttonStyle(CoorditContentActionButtonStyle(prominence: .primary))
            .accessibilityIdentifier("closet-camera-continue")
            Spacer()
        }
        .padding(.horizontal, metrics.value(22))
        .fullScreenCover(isPresented: $showsCapture) {
            CoorditFitLabCameraComparison(coordinator: coordinator, analyze: { measurement in
                draft.method = .photo
                draft.name = measurement.garmentName
                let dimensions = measurement.isLower ? CoorditGarmentDimension.lower : CoorditGarmentDimension.upper
                let values = dimensions.map { dimension in measurement.measurementValues[dimension.measurementKey].map { String($0) } ?? "" }
                draft.measurement1 = values[0]; draft.measurement2 = values[1]
                draft.measurement3 = values[2]; draft.measurement4 = values[3]
                draft.cameraMeasurement = measurement
                draft.garmentImageData = coordinator.cameraCapture.garmentPhotoData
                showsCapture = false
                onSubmit()
            }, capture: coordinator.cameraCapture, savesReferenceOnly: true)
        }
    }
}
#endif
