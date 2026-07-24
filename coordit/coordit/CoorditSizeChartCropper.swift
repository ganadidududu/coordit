import SwiftUI

#if os(iOS) && canImport(UIKit)
import UIKit

enum CoorditSizeChartImageCropper {
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    static func crop(_ image: UIImage, normalizedRect: CGRect) -> UIImage? {
        let source = normalized(image)
        guard let cgImage = source.cgImage else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let pixelRect = CGRect(
            x: normalizedRect.minX * bounds.width,
            y: normalizedRect.minY * bounds.height,
            width: normalizedRect.width * bounds.width,
            height: normalizedRect.height * bounds.height
        ).integral.intersection(bounds)
        guard pixelRect.width >= 2, pixelRect.height >= 2,
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }
}

struct CoorditSizeChartCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var cropRect = CGRect(x: 0.06, y: 0.18, width: 0.88, height: 0.64)
    @State private var dragStart: CGRect?

    private let minimumSide: CGFloat = 0.18

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 5) {
                    Text("사이즈표 부분만 맞춰주세요")
                        .font(CoorditTypography.gmarketBold(size: 18))
                    Text("표 바깥의 상품 사진과 설명을 빼면 OCR 정확도가 좋아져요.")
                        .font(CoorditTypography.gmarketMedium(size: 11))
                        .foregroundStyle(Color.black.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)

                GeometryReader { proxy in
                    let imageRect = aspectFitRect(imageSize: image.size, in: proxy.size)
                    ZStack {
                        Color.black.opacity(0.92)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)

                        cropOverlay(in: imageRect)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityIdentifier("size-chart-cropper")

                HStack(spacing: 10) {
                    Button("취소", action: onCancel)
                        .buttonStyle(
                            CoorditContentActionButtonStyle(
                                prominence: .secondary
                            )
                        )
                    Button("표 영역 사용", action: confirm)
                        .buttonStyle(
                            CoorditContentActionButtonStyle(
                                prominence: .primary
                            )
                        )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
            .padding(.top, 14)
            .background(CoorditDesignTokens.ColorToken.panel.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func cropOverlay(in imageRect: CGRect) -> some View {
        let rect = CGRect(
            x: imageRect.minX + cropRect.minX * imageRect.width,
            y: imageRect.minY + cropRect.minY * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )

        return ZStack {
            Path { path in
                path.addRect(imageRect)
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.54), style: FillStyle(eoFill: true))

            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .gesture(moveGesture(in: imageRect))

            ForEach(Corner.allCases, id: \.self) { corner in
                Button(action: {}) {
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(CoorditDesignTokens.ColorToken.ink, lineWidth: 2))
                        }
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain)
                    .position(position(for: corner, in: rect))
                    .simultaneousGesture(resizeGesture(corner, in: imageRect))
                    .accessibilityLabel("자르기 영역 \(corner.accessibilityName) 조절")
                    .accessibilityIdentifier("size-chart-crop-handle-\(corner.identifier)")
            }
        }
    }

    private func moveGesture(in imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? cropRect
                if dragStart == nil { dragStart = start }
                let dx = value.translation.width / imageRect.width
                let dy = value.translation.height / imageRect.height
                cropRect.origin.x = min(max(0, start.minX + dx), 1 - start.width)
                cropRect.origin.y = min(max(0, start.minY + dy), 1 - start.height)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func resizeGesture(_ corner: Corner, in imageRect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? cropRect
                if dragStart == nil { dragStart = start }
                let dx = value.translation.width / imageRect.width
                let dy = value.translation.height / imageRect.height
                var minX = start.minX
                var minY = start.minY
                var maxX = start.maxX
                var maxY = start.maxY
                if corner.isLeft { minX = min(max(0, start.minX + dx), maxX - minimumSide) }
                else { maxX = max(min(1, start.maxX + dx), minX + minimumSide) }
                if corner.isTop { minY = min(max(0, start.minY + dy), maxY - minimumSide) }
                else { maxY = max(min(1, start.maxY + dy), minY + minimumSide) }
                cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func position(for corner: Corner, in rect: CGRect) -> CGPoint {
        CGPoint(x: corner.isLeft ? rect.minX : rect.maxX, y: corner.isTop ? rect.minY : rect.maxY)
    }

    private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }

    private func confirm() {
        guard let cropped = CoorditSizeChartImageCropper.crop(image, normalizedRect: cropRect) else { return }
        onConfirm(cropped)
    }

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        var isLeft: Bool { self == .topLeft || self == .bottomLeft }
        var isTop: Bool { self == .topLeft || self == .topRight }
        var identifier: String {
            switch self {
            case .topLeft: "top-left"
            case .topRight: "top-right"
            case .bottomLeft: "bottom-left"
            case .bottomRight: "bottom-right"
            }
        }
        var accessibilityName: String {
            switch self {
            case .topLeft: "왼쪽 위"
            case .topRight: "오른쪽 위"
            case .bottomLeft: "왼쪽 아래"
            case .bottomRight: "오른쪽 아래"
            }
        }
    }
}
#endif
