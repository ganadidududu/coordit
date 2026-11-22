import SwiftUI
import WebKit

#if os(iOS)

/// "링크 가져오는 중" 화면.
///
/// 상품 페이지를 실제로 보여주면서 사이즈표를 추출한다.
/// 사용자는 아무것도 누르지 않는다. 결과가 나오면 자동으로 넘어가고,
/// 실패하면 서버 가져오기로, 그것도 안 되면 직접 입력으로 이어진다.
struct CoorditFitLabWebImportScreen: View {
    let url: URL
    let metrics: CoorditResponsiveMetrics
    let onExtracted: (CoorditWebSizeChart) -> Void
    let onFallbackToServer: () -> Void
    let onCancel: () -> Void

    @State private var status: Status = .loading
    @State private var imageTask: Task<Void, Never>?

    private enum Status {
        case loading
        case readingImage
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            statusRow
            CoorditProductWebView(
                url: url,
                onExtracted: handleExtracted,
                onFailure: { _ in onFallbackToServer() },
                timeout: 18
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.white.ignoresSafeArea())
        .onDisappear {
            imageTask?.cancel()
            imageTask = nil
        }
        .accessibilityIdentifier("fitlab-web-import")
    }

    /// 지금 어느 판매처의 상품 페이지를 보고 있는지 알려주는 인앱 브라우저식 상단 바.
    private var topBar: some View {
        ZStack {
            HStack(spacing: metrics.value(5)) {
                if url.scheme?.lowercased() == "https" {
                    Image(systemName: "lock.fill")
                        .font(.system(size: metrics.value(10)))
                }
                Text(url.host(percentEncoded: false) ?? "상품 페이지")
                    .font(.system(size: metrics.value(13), weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(Color.black.opacity(0.7))
            .padding(.horizontal, metrics.value(64))

            HStack {
                Button("취소", action: onCancel)
                    .font(.system(size: metrics.value(15), weight: .medium))
                    .foregroundStyle(Color.black)
                    .accessibilityIdentifier("fitlab-web-import-cancel")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.value(16))
        }
        .frame(height: metrics.value(44))
        .background(Color.white)
    }

    /// 상품 페이지를 전혀 가리지 않도록 페이지 위쪽에 따로 둔 한 줄짜리 진행 표시.
    private var statusRow: some View {
        HStack(spacing: metrics.value(8)) {
            ProgressView()
                .controlSize(.small)
            Text(statusText)
                .font(.system(size: metrics.value(12), weight: .medium))
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, metrics.value(7))
        .background(Color.black.opacity(0.05))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fitlab-web-import-status")
    }

    private var statusText: String {
        switch status {
        case .loading: "상품 페이지에서 사이즈 정보를 확인하는 중이에요"
        case .readingImage: "사이즈표 이미지를 읽는 중이에요"
        }
    }

    private func handleExtracted(_ chart: CoorditWebSizeChart) {
        guard chart.rows.isEmpty else {
            onExtracted(chart)
            return
        }
        guard chart.requiresVisionOCR, chart.sizeChartImageURL != nil else {
            onFallbackToServer()
            return
        }
        // 표가 이미지로만 있는 페이지: 그 이미지를 기기에서 OCR로 읽는다.
        status = .readingImage
        imageTask = Task { @MainActor in
            let recognized = try? await CoorditWebSizeChartImageReader.read(chart)
            guard !Task.isCancelled else { return }
            if let recognized {
                onExtracted(recognized)
            } else {
                onFallbackToServer()
            }
        }
    }
}

#endif
