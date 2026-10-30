import XCTest
import Vision
@testable import coordit

@MainActor
final class CoorditGarmentDatasetEvaluationTests: XCTestCase {
    private struct Sample: Decodable {
        let file: String
        let category: CoorditFitLabCategory
        let width: Double
        let height: Double
        let segmentation: [[[Double]]]
    }

    func testPublicFlatLayBenchmark() async throws {
        let bundle = Bundle(for: Self.self)
        let manifest = try XCTUnwrap(bundle.url(forResource: "camera-dataset", withExtension: "json"))
        let samples = try JSONDecoder().decode([Sample].self, from: Data(contentsOf: manifest))
        XCTAssertEqual(samples.count, 16)
        var rows: [String] = ["file,contours_iou,foreground_iou,tapped_iou,foreground_used,endpoints,card_candidates"]
        for sample in samples {
            let name = (sample.file as NSString).deletingPathExtension
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "png"))
            let data = try Data(contentsOf: url)
            if sample.file == samples.first?.file {
                do {
                    let outlines = try await CoorditGarmentOutlineDetector.foregroundOutlines(handler: VNImageRequestHandler(data: data), hint: nil)
                    print("GARMENT_FOREGROUND_RUNTIME outlines=\(outlines.count)")
                } catch { print("GARMENT_FOREGROUND_RUNTIME error=\(error)") }
            }
            let expected = sample.segmentation.map { polygon in
                polygon.map { CoorditMeasurementPoint(x: $0[0] / sample.width, y: $0[1] / sample.height) }
            }
            let hint = (0..<64).flatMap { row in (0..<128).map { column in
                CoorditMeasurementPoint(x: (Double(column) + 0.5) / 128, y: (Double(row) + 0.5) / 64)
            }}.filter { point in expected.contains { CoorditGarmentOutlineDetector.contains(point, in: $0) } }
            let center = CoorditMeasurementPoint(x: hint.map(\.x).reduce(0, +) / Double(hint.count), y: hint.map(\.y).reduce(0, +) / Double(hint.count))
            let tap = try XCTUnwrap(hint.min { hypot($0.x - center.x, $0.y - center.y) < hypot($1.x - center.x, $1.y - center.y) })
            let detector = CoorditGarmentOutlineDetector()
            let baseline = try await detector.detect(data, category: sample.category, useForegroundFallback: false)
            let automatic = try await detector.detect(data, category: sample.category)
            let assisted = try await detector.detect(data, category: sample.category, garmentHint: tap)
            let row = "\(sample.file),\(iou(baseline.outline, expected)),\(iou(automatic.outline, expected)),\(iou(assisted.outline, expected)),\(automatic.usedForegroundMask),\(automatic.endpoints.count),\(automatic.corners.count)"
            rows.append(row)
            print("GARMENT_BENCHMARK \(row)")
        }
        let result = XCTAttachment(string: rows.joined(separator: "\n"))
        result.name = "artf-16-localization.csv"
        result.lifetime = .keepAlways
        add(result)
    }

    private func iou(_ prediction: [CoorditMeasurementPoint], _ expected: [[CoorditMeasurementPoint]]) -> Double {
        var intersection = 0, union = 0
        for y in 0..<64 {
            for x in 0..<128 {
                let point = CoorditMeasurementPoint(x: (Double(x) + 0.5) / 128, y: (Double(y) + 0.5) / 64)
                let actual = CoorditGarmentOutlineDetector.contains(point, in: prediction)
                let truth = expected.contains { CoorditGarmentOutlineDetector.contains(point, in: $0) }
                if actual && truth { intersection += 1 }
                if actual || truth { union += 1 }
            }
        }
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }
}
