import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if os(iOS)

/// 표가 이미지로만 있는 상품 페이지에서 그 이미지를 받아 Vision OCR로 읽는다.
///
/// 화면 캡처 대신 원본 이미지를 직접 받는다. 캡처는 뷰포트 폭으로 축소돼 글자가 작아지고
/// 스크롤·지연 로딩 타이밍에 좌우되지만, 원본은 해상도가 그대로라 OCR이 안정적이다.
enum CoorditWebSizeChartImageReader {
    private static let maxImageBytes = 15 * 1024 * 1024
    private static let maxTiles = 12

    static func read(
        _ chart: CoorditWebSizeChart,
        ocr: any CoorditFitLabOCRServicing = CoorditFitLabVisionOCRService()
    ) async throws -> CoorditWebSizeChart {
        guard let imageURL = chart.sizeChartImageURL,
              let scheme = imageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { throw failure }

        var request = URLRequest(url: imageURL, timeoutInterval: 10)
        // 이미지 CDN의 핫링크 차단을 피하려고 상품 페이지에서 요청한 것처럼 보낸다.
        if let referer = chart.productURL?.absoluteString {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              !data.isEmpty, data.count <= maxImageBytes
        else { throw failure }

        let limit = maxTiles
        let pieces = await Task.detached(priority: .userInitiated) {
            Self.tiles(from: data, limit: limit)
        }.value
        // 표가 조각 경계에 걸리면 그 조각은 일부 행·열만 읽는다. 치수를 가장 많이 읽은 조각을 쓴다.
        var best: [CoorditFitLabSizeDraft] = []
        var bestScore = 0
        for tile in pieces {
            try Task.checkCancellation()
            guard let result = try? await ocr.recognizeSizeChart(imageData: tile), result.didFindTable else { continue }
            let score = result.draft.sizes.reduce(0) { $0 + $1.measurements.count }
            guard score > bestScore else { continue }
            best = result.draft.sizes
            bestScore = score
        }
        guard !best.isEmpty else { throw failure }
        return CoorditWebSizeChart(
            productName: chart.productName,
            brand: chart.brand,
            mallName: chart.mallName,
            productURL: chart.productURL,
            rawHeaders: chart.rawHeaders,
            rows: best.map { CoorditWebSizeChart.Row(sizeLabel: $0.label, measurements: $0.measurements) },
            requiresVisionOCR: false,
            sizeChartImageURL: chart.sizeChartImageURL
        )
    }

    private static var failure: CoorditWebSizeChartError {
        .init(kind: .sizeTableNotFound, message: "사이즈표 이미지를 읽지 못했어요.")
    }

    /// 상세페이지 통이미지처럼 세로로 긴 이미지는 글자가 전체 높이 대비 너무 작아
    /// Vision이 놓친다. 겹치는 조각으로 잘라 조각마다 읽는다.
    private nonisolated static func tiles(from data: Data, limit: Int) -> [Data] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.height > image.width * 2
        else { return [data] }

        let tileHeight = image.width * 3 / 2
        let step = tileHeight * 3 / 4
        var tiles: [Data] = []
        var y = 0
        while y < image.height, tiles.count < limit {
            let rect = CGRect(x: 0, y: y, width: image.width, height: min(tileHeight, image.height - y))
            if let cropped = image.cropping(to: rect), let encoded = png(cropped) { tiles.append(encoded) }
            y += step
        }
        return tiles.isEmpty ? [data] : tiles
    }

    private nonisolated static func png(_ image: CGImage) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

#endif
