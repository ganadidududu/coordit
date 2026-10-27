#if os(iOS)
import Foundation
import ImageIO
import Vision
import os

struct CoorditGarmentOutlineProposal: Sendable {
    let corners: [CoorditMeasurementPoint]
    let outline: [CoorditMeasurementPoint]
    let endpoints: [CoorditMeasurementPoint]
    let isLower: Bool
    var usedForegroundMask = false
}

actor CoorditGarmentOutlineDetector {
    private let logger = Logger(subsystem: "com.inseong.coordit", category: "garment-detection")
    func detect(_ data: Data, category: CoorditFitLabCategory? = nil, cardHint: CoorditMeasurementPoint? = nil,
                garmentHint: CoorditMeasurementPoint? = nil, useForegroundFallback: Bool = true) throws -> CoorditGarmentOutlineProposal {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CoorditGarmentMeasurementError.invalidPoint
        }
        let handler = VNImageRequestHandler(cgImage: image)
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumAspectRatio = 0.3
        rectangles.maximumAspectRatio = 1
        rectangles.minimumSize = 0.02
        rectangles.minimumConfidence = 0.7
        rectangles.maximumObservations = 24
        try handler.perform([rectangles])
        let candidates = (rectangles.results ?? []).filter { rectangle in
            func distance(_ first: CGPoint, _ second: CGPoint) -> Double {
                hypot((first.x - second.x) * Double(image.width), (first.y - second.y) * Double(image.height))
            }
            let width = (distance(rectangle.topLeft, rectangle.topRight) + distance(rectangle.bottomLeft, rectangle.bottomRight)) / 2
            let height = (distance(rectangle.topLeft, rectangle.bottomLeft) + distance(rectangle.topRight, rectangle.bottomRight)) / 2
            let ratio = min(width, height) / max(width, height)
            let polygon = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft].map {
                CoorditMeasurementPoint(x: $0.x, y: 1 - $0.y)
            }
            return rectangle.boundingBox.width * rectangle.boundingBox.height < 0.12 && (0.55...0.72).contains(ratio)
                && (cardHint.map { Self.contains($0, in: polygon) } ?? true)
        }
        var corners: [CoorditMeasurementPoint] = []
        if (candidates.count == 1 || cardHint != nil), let card = candidates.max(by: { $0.confidence < $1.confidence }) {
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
            request.maximumImageDimension = 2048
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
                guard polygon.count >= (category == .skirt ? 4 : 8),
                      polygon.allSatisfy({ $0.x > 0.015 && $0.x < 0.985 && $0.y > 0.015 && $0.y < 0.985 }) else { continue }
                let area = Self.area(polygon)
                if area > 0.025 && area < 0.85,
                   garmentHint.map({ Self.contains($0, in: polygon) }) ?? true { outlines.append(polygon) }
            }
        }
        if let cardContour = cardContours.max(by: { $0.count < $1.count }),
           let refined = Self.refineCard(corners, contour: cardContour, width: Double(image.width), height: Double(image.height)) {
            corners = refined
        }
        let ordered = outlines.sorted { Self.area($0) > Self.area($1) }
        for outline in ordered {
            if let proposed = Self.landmarks(outline, category: category) {
                return .init(corners: corners, outline: outline, endpoints: proposed.points, isLower: proposed.isLower)
            }
        }
        if useForegroundFallback, !Task.isCancelled {
          do {
            let foreground = try Self.foregroundOutlines(handler: handler, hint: garmentHint)
            for outline in foreground.sorted(by: { Self.area($0) > Self.area($1) }) {
                if let proposed = Self.landmarks(outline, category: category) {
                    return .init(corners: corners, outline: outline, endpoints: proposed.points, isLower: proposed.isLower, usedForegroundMask: true)
                }
            }
            if let outline = foreground.max(by: { Self.area($0) < Self.area($1) }) {
                return .init(corners: corners, outline: outline, endpoints: [], isLower: category?.garmentKind == .lower, usedForegroundMask: true)
            }
          } catch {
            logger.debug("Foreground fallback unavailable: \(error.localizedDescription, privacy: .public)")
          }
        }
        guard let outline = ordered.first else {
            return .init(corners: corners, outline: [], endpoints: [], isLower: false)
        }
        return .init(corners: corners, outline: outline, endpoints: [], isLower: category?.garmentKind == .lower)
    }

    static func foregroundOutlines(handler: VNImageRequestHandler, hint: CoorditMeasurementPoint?) throws -> [[CoorditMeasurementPoint]] {
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first else { return [] }
        var outlines: [[CoorditMeasurementPoint]] = []
        for instance in observation.allInstances {
            try Task.checkCancellation()
            let mask = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler)
            let contours = VNDetectContoursRequest()
            contours.detectsDarkOnLight = false
            contours.maximumImageDimension = 1024
            try VNImageRequestHandler(cvPixelBuffer: mask).perform([contours])
            guard let result = contours.results?.first else { continue }
            for contour in result.topLevelContours {
                let polygon = try contour.polygonApproximation(epsilon: 0.004).normalizedPoints.map {
                    CoorditMeasurementPoint(x: Double($0.x), y: 1 - Double($0.y))
                }
                guard (0.025...0.85).contains(Self.area(polygon)),
                      polygon.allSatisfy({ $0.x > 0.015 && $0.x < 0.985 && $0.y > 0.015 && $0.y < 0.985 }),
                      hint.map({ Self.contains($0, in: polygon) }) ?? true else { continue }
                outlines.append(polygon)
            }
        }
        return outlines
    }

    nonisolated static func contains(_ point: CoorditMeasurementPoint, in polygon: [CoorditMeasurementPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        for index in polygon.indices {
            let a = polygon[index], b = polygon[(index + 1) % polygon.count]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        }
        return inside
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
            let tolerance = max(4, length * 0.22)
            let straightEdges = contour.indices.compactMap { position -> (line: Line, length: Double)? in
                let first = contour[position], second = contour[(position + 1) % contour.count]
                let ax = first.x * width, ay = first.y * height
                let bx = second.x * width, by = second.y * height
                let sx = bx - ax, sy = by - ay, span = hypot(sx, sy)
                guard span > length * 0.4,
                      abs(sx * dx + sy * dy) / (span * length) > 0.97,
                      abs((ax - x) * dy - (ay - y) * dx) / length < tolerance,
                      abs((bx - x) * dy - (by - y) * dx) / length < tolerance else { return nil }
                let a = -sy / span, b = sx / span
                return (.init(a: a, b: b, c: a * ax + b * ay), span)
            }
            if let edge = straightEdges.max(by: { $0.length < $1.length }) {
                lines.append(edge.line)
                continue
            }
            let edge = contour.filter { point in
                let px = point.x * width - x, py = point.y * height - y
                let along = (px * dx + py * dy) / (length * length)
                return (0.2...0.8).contains(along) && abs(px * dy - py * dx) / length < tolerance
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
            let previous = corners[(index + 3) % 4]
            let edgeLength = hypot((corners[index].x - previous.x) * width, (corners[index].y - previous.y) * height)
            guard point.isNormalized, hypot((point.x - corners[index].x) * width, (point.y - corners[index].y) * height) < max(15, edgeLength * 0.3) else { return nil }
            result.append(point)
        }
        return result
    }

    nonisolated static func landmarks(_ polygon: [CoorditMeasurementPoint], category: CoorditFitLabCategory? = nil) -> (points: [CoorditMeasurementPoint], isLower: Bool)? {
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
        if category == .skirt {
            let waist = row(0.01), hip = row(0.22), hem = row(0.98)
            guard waist.count == 2, hip.count == 2, hem.count == 2,
                  hem[1] - hem[0] > (waist[1] - waist[0]) * 1.08 else { return nil }
            return ([point(waist[0], 0.01), point(waist[1], 0.01),
                     point(hip[0], 0.22), point(hip[1], 0.22),
                     point(waist[0], 0.01), point(waist[0], 0.99)], true)
        }
        if lower {
            let waist = row(0.025), hip = row(0.2)
            guard waist.count == 2, hip.count == 2,
                  let split = (20...85).first(where: { row(Double($0) / 100).count == 4 }) else { return nil }
            return ([point(waist[0], 0.025), point(waist[1], 0.025),
                     point(hip[0], 0.2), point(hip[1], 0.2),
                     point(middle, 0.025), point(middle, Double(split) / 100),
                     point(waist[0], 0.025), point(waist[0], 0.98)], true)
        }
        if category?.garmentKind == .lower { return nil }
        // A separated sleeve can create six intersections; the low body row stays clear of the cuffs.
        let torso = row(0.88)
        if torso.count == 2 {
            let bodyWidth = torso[1] - torso[0]
            let shoulderCandidates = polygon.filter { $0.y < minY + height * 0.46 }
            let tolerance = bodyWidth * 0.13
            let left = shoulderCandidates.filter { abs($0.x - torso[0]) < tolerance }.min { $0.y < $1.y }
            let right = shoulderCandidates.filter { abs($0.x - torso[1]) < tolerance }.min { $0.y < $1.y }
            if let left, let right, abs(left.y - right.y) < height * 0.12,
               let cuff = polygon.filter({ $0.y > right.y }).max(by: { $0.x < $1.x }),
               cuff.x - right.x > bodyWidth * 0.15,
               let neck = polygon.filter({ $0.x > left.x + bodyWidth * 0.12 && $0.x < middle - bodyWidth * 0.10 && $0.y <= left.y }).min(by: { $0.x < $1.x }) {
                let underarms = polygon.filter { $0.y > right.y + height * 0.08 && $0.y < minY + height * 0.65 && abs($0.x - torso[1]) < tolerance }
                if let underarm = underarms.min(by: { $0.y < $1.y }) {
                    let chestY = underarm.y + height * 0.01
                    let intersections = row((chestY - minY) / height)
                    let central = zip(intersections, intersections.dropFirst()).first { $0.0 < middle && $0.1 > middle }
                    if let central {
                        return ([left, right, .init(x: central.0, y: chestY), .init(x: central.1, y: chestY),
                                 neck, .init(x: neck.x, y: maxY), right, cuff], false)
                    }
                }
            }
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
