#if os(iOS)
import Foundation
import ImageIO
import Vision

struct CoorditGarmentOutlineProposal: Sendable {
    let corners: [CoorditMeasurementPoint]
    let outline: [CoorditMeasurementPoint]
    let endpoints: [CoorditMeasurementPoint]
    let isLower: Bool
}

actor CoorditGarmentOutlineDetector {
    func detect(_ data: Data) throws -> CoorditGarmentOutlineProposal {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let handler = VNImageRequestHandler(cgImage: image)
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumAspectRatio = 0.55
        rectangles.maximumAspectRatio = 0.72
        rectangles.minimumSize = 0.05
        rectangles.minimumConfidence = 0.7
        rectangles.maximumObservations = 8
        try handler.perform([rectangles])
        let candidates = (rectangles.results ?? []).filter { $0.boundingBox.width * $0.boundingBox.height < 0.12 }
        var corners: [CoorditMeasurementPoint] = []
        if candidates.count == 1, let card = candidates.first {
            corners = [card.topLeft, card.topRight, card.bottomRight, card.bottomLeft].map {
                .init(x: Double($0.x), y: 1 - Double($0.y))
            }
            let horizontal = hypot((corners[1].x - corners[0].x) * Double(image.width), (corners[1].y - corners[0].y) * Double(image.height))
            let vertical = hypot((corners[2].x - corners[1].x) * Double(image.width), (corners[2].y - corners[1].y) * Double(image.height))
            if vertical > horizontal { corners = [corners[1], corners[2], corners[3], corners[0]] }
        }
        var outlines: [[CoorditMeasurementPoint]] = []
        var cardContours: [[CoorditMeasurementPoint]] = []
        for (pivot, darkOnLight): (Float, Bool) in [(0.5, true), (0.98, false), (0.1, true)] {
            let request = VNDetectContoursRequest()
            request.detectsDarkOnLight = darkOnLight
            request.contrastAdjustment = pivot > 0.9 ? 20 : 3
            request.contrastPivot = NSNumber(value: pivot)
            request.maximumImageDimension = 1024
            try handler.perform([request])
            guard let observation = request.results?.first else { continue }
            for index in 0..<observation.contourCount {
                let contour = try observation.contour(at: index)
                let raw = contour.normalizedPoints.map { CoorditMeasurementPoint(x: Double($0.x), y: 1 - Double($0.y)) }
                if corners.count == 4, Self.area(raw) < 0.12, Self.area(raw) > 0.002,
                   let x = raw.map(\.x).min(), let right = raw.map(\.x).max(),
                   let y = raw.map(\.y).min(), let bottom = raw.map(\.y).max() {
                    let centerX = corners.map(\.x).reduce(0, +) / 4
                    let centerY = corners.map(\.y).reduce(0, +) / 4
                    if x < centerX && centerX < right && y < centerY && centerY < bottom { cardContours.append(raw) }
                }
                let polygon = try contour.polygonApproximation(epsilon: 0.004).normalizedPoints.map { CoorditMeasurementPoint(x: Double($0.x), y: 1 - Double($0.y)) }
                guard polygon.count >= 8,
                      polygon.allSatisfy({ $0.x > 0.015 && $0.x < 0.985 && $0.y > 0.015 && $0.y < 0.985 }) else { continue }
                let area = Self.area(polygon)
                if area > 0.12 && area < 0.85 { outlines.append(polygon) }
            }
        }
        if let cardContour = cardContours.max(by: { $0.count < $1.count }),
           let refined = Self.refineCard(corners, contour: cardContour, width: Double(image.width), height: Double(image.height)) {
            corners = refined
        }
        guard let outline = outlines.max(by: { Self.area($0) < Self.area($1) }),
              let proposed = Self.landmarks(outline) else {
            return .init(corners: corners, outline: [], endpoints: [], isLower: false)
        }
        return .init(corners: corners, outline: outline, endpoints: proposed.points, isLower: proposed.isLower)
    }

    nonisolated static func area(_ points: [CoorditMeasurementPoint]) -> Double {
        guard points.count > 2 else { return 0 }
        return abs(points.indices.reduce(0) { sum, index in
            let next = points[(index + 1) % points.count]
            return sum + points[index].x * next.y - next.x * points[index].y
        }) / 2
    }

    private nonisolated static func refineCard(_ corners: [CoorditMeasurementPoint], contour: [CoorditMeasurementPoint], width: Double, height: Double) -> [CoorditMeasurementPoint]? {
        struct Line { let a: Double; let b: Double; let c: Double }
        var lines: [Line] = []
        for index in 0..<4 {
            let start = corners[index], end = corners[(index + 1) % 4]
            let x = start.x * width, y = start.y * height
            let dx = (end.x - start.x) * width, dy = (end.y - start.y) * height
            let length = hypot(dx, dy)
            guard length > 0 else { return nil }
            let edge = contour.filter { point in
                let px = point.x * width - x, py = point.y * height - y
                let along = (px * dx + py * dy) / (length * length)
                return (0.2...0.8).contains(along) && abs(px * dy - py * dx) / length < max(3, length * 0.08)
            }
            guard edge.count >= 8 else { return nil }
            let meanX = edge.map { $0.x * width }.reduce(0, +) / Double(edge.count)
            let meanY = edge.map { $0.y * height }.reduce(0, +) / Double(edge.count)
            var xx = 0.0, yy = 0.0, xy = 0.0
            for point in edge {
                let px = point.x * width - meanX, py = point.y * height - meanY
                xx += px * px; yy += py * py; xy += px * py
            }
            let angle = 0.5 * atan2(2 * xy, xx - yy)
            let a = -sin(angle), b = cos(angle)
            lines.append(.init(a: a, b: b, c: a * meanX + b * meanY))
        }
        var result: [CoorditMeasurementPoint] = []
        for index in 0..<4 {
            let first = lines[(index + 3) % 4], second = lines[index]
            let determinant = first.a * second.b - second.a * first.b
            guard abs(determinant) > 0.01 else { return nil }
            let point = CoorditMeasurementPoint(x: (first.c * second.b - second.c * first.b) / determinant / width,
                                               y: (first.a * second.c - second.a * first.c) / determinant / height)
            guard point.isNormalized, hypot((point.x - corners[index].x) * width, (point.y - corners[index].y) * height) < 15 else { return nil }
            result.append(point)
        }
        return result
    }

    nonisolated static func landmarks(_ polygon: [CoorditMeasurementPoint]) -> (points: [CoorditMeasurementPoint], isLower: Bool)? {
        guard let minY = polygon.map(\.y).min(), let maxY = polygon.map(\.y).max(),
              let minX = polygon.map(\.x).min(), let maxX = polygon.map(\.x).max(),
              maxY - minY > 0.25, maxX - minX > 0.2 else { return nil }
        let height = maxY - minY, width = maxX - minX
        func row(_ fraction: Double) -> [Double] {
            let y = minY + height * fraction
            return polygon.indices.compactMap { index -> Double? in
                let a = polygon[index], b = polygon[(index + 1) % polygon.count]
                guard (a.y <= y && b.y > y) || (b.y <= y && a.y > y) else { return nil }
                return a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
            }.sorted()
        }
        func point(_ x: Double, _ fraction: Double) -> CoorditMeasurementPoint { .init(x: x, y: minY + height * fraction) }
        let bottom = row(0.85), middle = (minX + maxX) / 2
        let lower = bottom.count == 4 && bottom[2] - bottom[1] > width * 0.04
        if lower {
            let waist = row(0.025), hip = row(0.2)
            guard waist.count == 2, hip.count == 2,
                  let split = (20...75).first(where: { row(Double($0) / 100).count == 4 }) else { return nil }
            return ([point(waist[0], 0.025), point(waist[1], 0.025),
                     point(hip[0], 0.2), point(hip[1], 0.2),
                     point(middle, 0.025), point(middle, Double(split) / 100),
                     point(waist[0], 0.025), point(waist[0], 0.98)], true)
        }
        let body = row(0.65), sleeves = row(0.22)
        guard body.count == 2, sleeves.count == 2,
              sleeves[1] - sleeves[0] > (body[1] - body[0]) * 1.15 else { return nil }
        let top = polygon.filter { $0.y < minY + height * 0.17 }
        guard let leftShoulder = top.min(by: { $0.x < $1.x }),
              let rightShoulder = top.max(by: { $0.x < $1.x }),
              let sleeveEnd = polygon.max(by: { $0.x < $1.x }),
              let neck = top.filter({ $0.x < middle }).min(by: { $0.y < $1.y }) else { return nil }
        let chestFraction = (25...55).first { value in
            let intersections = row(Double(value) / 100)
            return intersections.count == 2 && intersections[1] - intersections[0] <= (body[1] - body[0]) * 1.04
        }.map { Double($0) / 100 } ?? 0.4
        let chest = row(chestFraction)
        guard chest.count == 2 else { return nil }
        return ([leftShoulder, rightShoulder, point(chest[0], chestFraction), point(chest[1], chestFraction),
                 neck, .init(x: neck.x, y: maxY), rightShoulder, sleeveEnd], false)
    }
}
#endif
