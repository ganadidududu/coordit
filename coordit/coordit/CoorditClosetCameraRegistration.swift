#if os(iOS)
import SwiftUI

struct CoorditClosetCameraRegistration: View {
    @EnvironmentObject private var backendSession: CoorditBackendSessionStore
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
        .task(id: backendSession.session?.accessToken) {
            coordinator.configureLandmarkGateway(using: backendSession.session.map {
                CoorditFitLabHTTPAPI(baseURL: CoorditBackendConfig.baseURL(), accessToken: $0.accessToken)
            })
        }
        .fullScreenCover(isPresented: $showsCapture) {
            CoorditFitLabCameraComparison(coordinator: coordinator, analyze: { measurement in
                draft.applyCameraMeasurement(measurement, photo: coordinator.cameraCapture.garmentPhotoData)
                showsCapture = false
                onSubmit()
            }, capture: coordinator.cameraCapture, savesReferenceOnly: true)
        }
    }
}
#endif
