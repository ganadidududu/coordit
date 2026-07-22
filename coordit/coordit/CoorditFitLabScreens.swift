import SwiftUI
import UIKit

#if os(iOS)
struct CoorditFitLabFamilyView: View {
    let currentRoute: CoorditFrameRoute
    let referenceItems: [CoorditClosetItem]
    let onRouteChange: (CoorditFrameRoute) -> Void

    @EnvironmentObject var backendSession: CoorditBackendSessionStore
    @State private var recommendation: CoorditFitRecommendation?
    @State private var activeCategory: CoorditClosetCategory = .top

    init(
        currentRoute: CoorditFrameRoute,
        referenceItems: [CoorditClosetItem] = [],
        onRouteChange: @escaping (CoorditFrameRoute) -> Void
    ) {
        self.currentRoute = currentRoute
        self.referenceItems = referenceItems
        self.onRouteChange = onRouteChange
    }

    var body: some View {
        CoorditScreenScaffold(route: currentRoute, onRouteChange: onRouteChange, contentTop: 115) { metrics in
            VStack(spacing: metrics.value(22)) {
                CoorditFitLabTitleCard(
                    title: currentRoute == .fitLabHistoryDetail ? "FIT DETAIL" : "FIT LAB",
                    metrics: metrics
                ) {
                    onRouteChange(.main04)
                }
                .padding(.horizontal, metrics.value(15))

                switch currentRoute {
                case .fitLabInput:
                    CoorditFitLabInputScreen(metrics: metrics) { sizeChartImageData in
                        startFitRecommendation(sizeChartImageData: sizeChartImageData)
                    }
                case .fitLabLoading:
                    CoorditFitLabLoadingScreen(metrics: metrics)
                case .fitLabResultTop:
                    CoorditFitLabResultScreen(variant: .top, recommendation: recommendation, metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabResultBottom:
                    CoorditFitLabResultScreen(variant: .bottom, recommendation: recommendation, metrics: metrics, onRouteChange: onRouteChange)
                case .fitLabHistoryRegister:
                    CoorditFitLabHistoryRegisterScreen(
                        variant: activeCategory == .bottom ? .bottom : .top,
                        recommendation: recommendation,
                        metrics: metrics,
                        onRouteChange: onRouteChange
                    )
                case .fitLabHistoryDetail:
                    CoorditFitLabHistoryDetailScreen(metrics: metrics, onRouteChange: onRouteChange)
                default:
                    CoorditFitLabInputScreen(metrics: metrics) { sizeChartImageData in
                        startFitRecommendation(sizeChartImageData: sizeChartImageData)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(currentRoute.fitLabAccessibilityIdentifier)
        }
    }

    private func startFitRecommendation(sizeChartImageData: Data?) {
        let category = referenceItems.first?.category ?? .top
        activeCategory = category
        recommendation = nil
        onRouteChange(.fitLabLoading)

        Task { @MainActor in
            guard let nextRecommendation = await backendSession.recommendFitLabTarget(
                category: category,
                sizeChartImageData: sizeChartImageData
            ) else {
                onRouteChange(.fitLabInput)
                return
            }
            recommendation = nextRecommendation
            onRouteChange(category.resultRoute)
        }
    }
}

struct CoorditFitLabScreens: View {
    let currentRoute: CoorditFrameRoute
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        CoorditFitLabFamilyView(currentRoute: currentRoute, onRouteChange: onRouteChange)
    }
}

private struct CoorditFitLabInputScreen: View {
    let metrics: CoorditResponsiveMetrics
    let onAnalyze: (Data?) -> Void

    @State private var selectedImageData: Data?
    @State private var selectedPhotoSource: CoorditFitLabPhotoSource?
    @State private var isCameraUnavailableAlertPresented = false

    var body: some View {
        VStack(spacing: metrics.value(14)) {
            HStack(spacing: metrics.value(11)) {
                Button {
                    selectedPhotoSource = .gallery
                } label: {
                    CoorditFitLabSourceButtonSurface(title: "갤러리에서 추가", metrics: metrics)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitlab-add-from-gallery")

                Button {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        isCameraUnavailableAlertPresented = true
                        return
                    }
                    selectedPhotoSource = .camera
                } label: {
                    CoorditFitLabSourceButtonSurface(title: "카메라에서 추가", metrics: metrics)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fitlab-add-from-camera")
            }
            .padding(metrics.value(9))
            .background(
                CoorditFitLabTexturedPanel(cornerRadius: metrics.value(7), intensity: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
            .shadow(color: CoorditFitLabPalette.ink.opacity(0.28), radius: metrics.value(8), y: metrics.value(3))

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CoorditFitLabPalette.surface,
                                Color(red: 244 / 255, green: 246 / 255, blue: 250 / 255),
                                Color(red: 230 / 255, green: 234 / 255, blue: 244 / 255),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        CoorditFitLabSubtleNoise()
                            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous))
                            .opacity(0.26)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.value(7), style: .continuous)
                            .stroke(Color.black.opacity(0.15), lineWidth: metrics.value(0.8))
                    )

                CoorditFitLabPhotoPreviewCard(imageData: selectedImageData, metrics: metrics) {
                    onAnalyze(selectedImageData)
                }
                .frame(height: metrics.value(276))
                .padding(.horizontal, metrics.value(12))
                .padding(.top, metrics.value(31))
                .shadow(color: .black.opacity(0.09), radius: metrics.value(20), y: metrics.value(10))
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.value(495))
            .shadow(color: .black.opacity(0.08), radius: metrics.value(14), y: metrics.value(5))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.value(33))
        .sheet(item: $selectedPhotoSource) { source in
            CoorditFitLabImagePicker(source: source, imageData: $selectedImageData)
                .ignoresSafeArea()
        }
        .alert("카메라를 사용할 수 없어요", isPresented: $isCameraUnavailableAlertPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("현재 기기에서는 카메라가 지원되지 않습니다. 갤러리에서 사진을 선택해주세요.")
        }
    }
}

private enum CoorditFitLabPhotoSource: String, Identifiable {
    case gallery
    case camera

    var id: String { rawValue }

    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .gallery:
            return .photoLibrary
        case .camera:
            return .camera
        }
    }
}

private struct CoorditFitLabSourceButtonSurface: View {
    let title: String
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        Text(title)
            .font(CoorditTypography.gmarketMedium(size: metrics.value(15), relativeTo: .body))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: metrics.value(65))
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 250 / 255, green: 251 / 255, blue: 254 / 255),
                            Color(red: 225 / 255, green: 230 / 255, blue: 243 / 255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    CoorditFitLabSubtleNoise()
                        .opacity(0.38)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.value(7))
                    .stroke(.white.opacity(0.8), lineWidth: metrics.value(1))
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.value(7)))
            .shadow(color: .black.opacity(0.12), radius: metrics.value(9), y: metrics.value(4))
    }
}

private struct CoorditFitLabPhotoPreviewCard: View {
    let imageData: Data?
    let metrics: CoorditResponsiveMetrics
    let onAnalyze: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 251 / 255, green: 252 / 255, blue: 254 / 255),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous))
                    .overlay(alignment: .bottom) {
                        Button(action: onAnalyze) {
                            Text("핏 분석하기")
                                .font(CoorditTypography.gmarketBold(size: metrics.value(13)))
                                .foregroundStyle(.white)
                                .frame(width: metrics.value(132), height: metrics.value(34))
                                .background(CoorditFitLabPalette.ink.opacity(0.88))
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.18), radius: metrics.value(8), y: metrics.value(3))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, metrics.value(16))
                        .accessibilityIdentifier("fitlab-analyze-selected-photo")
                    }
            } else {
                VStack(spacing: metrics.value(10)) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: metrics.value(32), weight: .semibold))
                        .foregroundStyle(CoorditFitLabPalette.ink.opacity(0.38))
                    Text("사진을 추가해주세요")
                        .font(CoorditTypography.gmarketMedium(size: metrics.value(13), relativeTo: .body))
                        .foregroundStyle(CoorditFitLabPalette.ink.opacity(0.52))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.value(8), style: .continuous))
        .accessibilityIdentifier("fitlab-photo-preview")
    }
}

private struct CoorditFitLabImagePicker: UIViewControllerRepresentable {
    let source: CoorditFitLabPhotoSource
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source.uiKitSourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CoorditFitLabImagePicker

        init(parent: CoorditFitLabImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.86)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct CoorditFitLabLoadingScreen: View {
    let metrics: CoorditResponsiveMetrics

    var body: some View {
        VStack(spacing: metrics.value(22)) {
            Spacer(minLength: metrics.value(158))
            ZStack {
                Image(CoorditAssetNames.loadingMannequin)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(58), height: metrics.value(82))
                    .opacity(0.28)
                Image(CoorditAssetNames.loadingOrbit)
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.value(85), height: metrics.value(44))
                    .opacity(0.75)
            }
            Text("핏 스코어 계산 중 . . .")
                .font(CoorditTypography.gmarketMedium(size: metrics.value(16), relativeTo: .body))
                .foregroundStyle(Color.black.opacity(0.76))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CoorditFitLabResultScreen: View {
    let variant: CoorditFitLabResultVariant
    let recommendation: CoorditFitRecommendation?
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(14)) {
            HStack(spacing: metrics.value(8)) {
                CoorditFitLabMannequinPanel(assetName: variant.assetName, metrics: metrics)
                    .frame(width: metrics.value(109), height: metrics.value(240))

                CoorditFitLabScoreCard(variant: variant, recommendation: recommendation, metrics: metrics)
                    .frame(width: metrics.value(229), height: metrics.value(240))
            }

            CoorditFitLabDescriptionCard(metrics: metrics, compact: false, onDetail: nil)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(263))

            CoorditFitLabPrimaryButton(title: "히스토리에 추가", metrics: metrics) {
                onRouteChange(.fitLabHistoryRegister)
            }
            .padding(.top, metrics.value(1))
        }
        .padding(.horizontal, metrics.value(28))
    }
}

private struct CoorditFitLabHistoryRegisterScreen: View {
    let variant: CoorditFitLabResultVariant
    let recommendation: CoorditFitRecommendation?
    let metrics: CoorditResponsiveMetrics
    let onRouteChange: (CoorditFrameRoute) -> Void

    var body: some View {
        VStack(spacing: metrics.value(12)) {
            HStack(spacing: metrics.value(8)) {
                CoorditFitLabMannequinPanel(assetName: variant.assetName, metrics: metrics)
                    .frame(width: metrics.value(109), height: metrics.value(240))

                CoorditFitLabScoreCard(variant: variant, recommendation: recommendation, metrics: metrics)
                    .frame(width: metrics.value(229), height: metrics.value(240))
            }

            CoorditFitLabDescriptionCard(metrics: metrics, compact: false, onDetail: nil)
                .frame(maxWidth: .infinity)
                .frame(height: metrics.value(263))

            CoorditFitLabPrimaryButton(title: "히스토리에 추가", metrics: metrics) {
                onRouteChange(.fitLabHistoryDetail)
            }
        }
        .padding(.horizontal, metrics.value(28))
    }
}

private extension CoorditFrameRoute {
    var fitLabAccessibilityIdentifier: String {
        switch self {
        case .fitLabInput,
             .fitLabLoading,
             .fitLabResultTop,
             .fitLabResultBottom,
             .fitLabHistoryRegister,
             .fitLabHistoryDetail:
            "coordit-screen-\(rawValue)"
        default:
            "coordit-screen-fitlab-input"
        }
    }
}
#endif
