import Foundation
import simd

enum CoorditGarmentDimension: String, Codable, CaseIterable, Identifiable, Sendable {
    case shoulder, chest, length, sleeve
    case waist, hip, rise, outseam

    static let upper: [Self] = [.shoulder, .chest, .length, .sleeve]
    static let lower: [Self] = [.waist, .hip, .rise, .outseam]

    var id: String { rawValue }
    var title: String {
        switch self {
        case .shoulder: "어깨"
        case .chest: "가슴 단면"
        case .length: "총장"
        case .sleeve: "소매"
        case .waist: "허리 단면"
        case .hip: "엉덩이 단면"
        case .rise: "밑위"
        case .outseam: "총장"
        }
    }
    var instruction: String {
        switch self {
        case .shoulder: "양쪽 어깨 봉제선의 끝점을 차례로 눌러주세요."
        case .chest: "양쪽 겨드랑이 아래의 끝점을 차례로 눌러주세요. 둘레가 아닌 단면 너비예요."
        case .length: "상품 사이즈표와 같은 시작점에서 밑단까지, 총장의 양 끝점을 눌러주세요."
        case .sleeve: "어깨 봉제선부터 소매 끝까지 눌러주세요. 목 중심에서 재는 화장과 달라요."
        case .waist: "허리 양 끝을 눌러주세요."
        case .hip: "엉덩이의 가장 넓은 양 끝을 눌러주세요."
        case .rise: "허리 중심부터 가랑이 봉제선까지 눌러주세요."
        case .outseam: "허리 옆선부터 밑단까지 눌러주세요."
        }
    }
    var measurementKey: String {
        switch self {
        case .shoulder: "shoulder_width"
        case .chest: "chest_width"
        case .length: "total_length"
        case .sleeve: "sleeve_length"
        case .waist: "waist_width"
        case .hip: "hip_width"
        case .rise: "rise"
        case .outseam: "outseam"
        }
    }
    var validRange: ClosedRange<Double> {
        switch self {
        case .shoulder: 15...100
        case .chest: 20...120
        case .length: 25...150
        case .sleeve: 3...90
        case .waist: 20...90
        case .hip: 25...100
        case .rise: 10...60
        case .outseam: 20...150
        }
    }
}

struct CoorditMeasurementPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    nonisolated var isNormalized: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

struct CoorditMeasurementVector: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double

    init(x: Double, y: Double, z: Double = 0) { self.x = x; self.y = y; self.z = z }
    init(_ vector: SIMD3<Float>) { x = Double(vector.x); y = Double(vector.y); z = Double(vector.z) }
    var simd: SIMD3<Float> { .init(Float(x), Float(y), Float(z)) }
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

struct CoorditMeasurementSegment: Codable, Equatable, Sendable {
    let start: CoorditMeasurementVector
    let end: CoorditMeasurementVector

    var centimeters: Double {
        let dx = end.x - start.x, dy = end.y - start.y, dz = end.z - start.z
        return sqrt(dx * dx + dy * dy + dz * dz) * 100
    }

    func resized(centimeters: Double, centered: Bool) -> Self? {
        let original = self.centimeters
        guard original.isFinite, original > 0, centimeters.isFinite, centimeters > 0 else { return nil }
        let ratio = centimeters / original
        let delta = CoorditMeasurementVector(x: (end.x - start.x) * ratio, y: (end.y - start.y) * ratio, z: (end.z - start.z) * ratio)
        if centered {
            let middle = CoorditMeasurementVector(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2, z: (start.z + end.z) / 2)
            return .init(start: .init(x: middle.x - delta.x / 2, y: middle.y - delta.y / 2, z: middle.z - delta.z / 2), end: .init(x: middle.x + delta.x / 2, y: middle.y + delta.y / 2, z: middle.z + delta.z / 2))
        }
        return .init(start: start, end: .init(x: start.x + delta.x, y: start.y + delta.y, z: start.z + delta.z))
    }
}

enum CoorditGarmentMeasurementError: LocalizedError, Equatable {
    case invalidCard, invalidPoint, invalidDimension(String), unstableTracking

    var errorDescription: String? {
        switch self {
        case .invalidCard: "카드 네 모서리를 왼쪽 위부터 시계 방향으로 다시 지정해주세요. 카드가 충분히 크게 보여야 해요."
        case .invalidPoint: "이 지점의 거리를 확인하지 못했어요. 평평한 옷 위의 끝점을 다시 눌러주세요."
        case .invalidDimension(let title): "\(title) 측정값을 확인해주세요. 옷을 평평하게 펴고 양 끝점을 다시 지정할 수 있어요."
        case .unstableTracking: "카메라 위치를 확인하는 중이에요. 옷을 천천히 비추고 다시 시도해주세요."
        }
    }
}

struct CoorditCardCalibration: Sendable {
    static let widthMeters = 0.08560
    static let heightMeters = 0.05398
    private let imageToPlane: [Double]
    private let planeToImage: [Double]

    init(corners: [CoorditMeasurementPoint], imageWidth: Double, imageHeight: Double) throws {
        guard corners.count == 4, corners.allSatisfy(\.isNormalized), imageWidth.isFinite, imageHeight.isFinite,
              imageWidth > 0, imageHeight > 0 else { throw CoorditGarmentMeasurementError.invalidCard }
        let polygon = corners.indices.map { index -> Double in
            let a = corners[index], b = corners[(index + 1) % 4], c = corners[(index + 2) % 4]
            return (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
        }
        guard polygon.allSatisfy({ $0 > 0.00001 }) else { throw CoorditGarmentMeasurementError.invalidCard }
        let edges = corners.indices.map { index -> Double in
            let a = corners[index], b = corners[(index + 1) % 4]
            return hypot((b.x - a.x) * imageWidth, (b.y - a.y) * imageHeight)
        }
        guard (edges.min() ?? 0) >= 60, (edges.max() ?? 0) >= 120 else { throw CoorditGarmentMeasurementError.invalidCard }
        let plane: [CoorditMeasurementPoint] = [.init(x: 0, y: 0), .init(x: Self.widthMeters, y: 0), .init(x: Self.widthMeters, y: Self.heightMeters), .init(x: 0, y: Self.heightMeters)]
        imageToPlane = try Self.solve(from: corners, to: plane)
        planeToImage = try Self.solve(from: plane, to: corners)
    }

    func worldPoint(_ point: CoorditMeasurementPoint) throws -> CoorditMeasurementVector {
        guard point.isNormalized, let mapped = Self.map(point, using: imageToPlane) else { throw CoorditGarmentMeasurementError.invalidPoint }
        return .init(x: mapped.x, y: mapped.y)
    }

    func imagePoint(_ point: CoorditMeasurementVector) -> CoorditMeasurementPoint? {
        guard point.isFinite else { return nil }
        return Self.map(.init(x: point.x, y: point.y), using: planeToImage)
    }

    private static func map(_ point: CoorditMeasurementPoint, using matrix: [Double]) -> CoorditMeasurementPoint? {
        let denominator = matrix[6] * point.x + matrix[7] * point.y + 1
        guard abs(denominator) > 1e-9 else { return nil }
        let x = (matrix[0] * point.x + matrix[1] * point.y + matrix[2]) / denominator
        let y = (matrix[3] * point.x + matrix[4] * point.y + matrix[5]) / denominator
        guard x.isFinite, y.isFinite else { return nil }
        return .init(x: x, y: y)
    }

    private static func solve(from source: [CoorditMeasurementPoint], to target: [CoorditMeasurementPoint]) throws -> [Double] {
        var rows: [[Double]] = []
        for index in 0..<4 {
            let p = source[index], q = target[index]
            rows.append([p.x, p.y, 1, 0, 0, 0, -q.x * p.x, -q.x * p.y, q.x])
            rows.append([0, 0, 0, p.x, p.y, 1, -q.y * p.x, -q.y * p.y, q.y])
        }
        for column in 0..<8 {
            guard let pivot = (column..<8).max(by: { abs(rows[$0][column]) < abs(rows[$1][column]) }), abs(rows[pivot][column]) > 1e-12 else { throw CoorditGarmentMeasurementError.invalidCard }
            rows.swapAt(column, pivot)
            let divisor = rows[column][column]
            for entry in column...8 { rows[column][entry] /= divisor }
            for row in 0..<8 where row != column {
                let factor = rows[row][column]
                for entry in column...8 { rows[row][entry] -= factor * rows[column][entry] }
            }
        }
        return rows.map { $0[8] }
    }
}

struct CoorditGarmentMeasurement: Codable, Equatable, Sendable, Identifiable {
    enum Method: String, Codable, Sendable { case lidar, card }
    let id: UUID
    let method: Method
    let measuredAt: Date
    let segments: [CoorditGarmentDimension: CoorditMeasurementSegment]
    let lengthBasis: String

    var isLower: Bool { segments[.waist] != nil }
    var dimensions: [CoorditGarmentDimension] { isLower ? .init(CoorditGarmentDimension.lower) : .init(CoorditGarmentDimension.upper) }

    init(id: UUID = UUID(), method: Method, measuredAt: Date = Date(), segments: [CoorditGarmentDimension: CoorditMeasurementSegment], lengthBasis: String) throws {
        let dimensions = segments[.waist] != nil ? CoorditGarmentDimension.lower : CoorditGarmentDimension.upper
        for dimension in dimensions {
            guard let segment = segments[dimension], segment.start.isFinite, segment.end.isFinite,
                  dimension.validRange.contains(segment.centimeters) else { throw CoorditGarmentMeasurementError.invalidDimension(dimension.title) }
        }
        guard (segments[.waist] != nil ? ["waist_to_hem"] : ["high_shoulder_to_hem", "back_neck_to_hem"]).contains(lengthBasis) else { throw CoorditGarmentMeasurementError.invalidDimension("총장 기준") }
        self.id = id; self.method = method; self.measuredAt = measuredAt; self.segments = segments; self.lengthBasis = lengthBasis
    }

    var measurementValues: [String: Double] {
        Dictionary(uniqueKeysWithValues: dimensions.compactMap { dimension in
            segments[dimension].map { (dimension.measurementKey, ($0.centimeters * 10).rounded() / 10) }
        })
    }
}
