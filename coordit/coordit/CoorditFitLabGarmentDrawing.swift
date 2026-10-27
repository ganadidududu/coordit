import SwiftUI

#if os(iOS)
/// Original mannequin anatomy with category-specific garments and occluded body contours.
struct CoorditFitLabGarmentDrawing: View {
    let category: CoorditFitLabCategory

    var body: some View {
        Image("CoorditFitGarment-\(category.rawValue)")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    func anchor(for key: CoorditFitLabMeasurementKey, in size: CGSize) -> CGPoint {
        let point: CGPoint
        switch key {
        case .shoulderWidth: point = CGPoint(x: 32, y: 73)
        case .chestWidth: point = CGPoint(x: 78, y: 108)
        case .totalLength: point = CGPoint(x: 39, y: category == .coat ? 207 : category == .jacket ? 179 : category == .tshirt ? 146 : 166)
        case .sleeveLength: point = CGPoint(x: category == .tshirt ? 99 : 102, y: category == .tshirt ? 101 : 179)
        case .waistWidth: point = CGPoint(x: 36, y: 8)
        case .hipWidth: point = CGPoint(x: 92, y: 32)
        case .rise: point = CGPoint(x: 63, y: 42)
        case .outseam: point = CGPoint(x: category == .skirt ? 24 : category == .shorts ? 83 : 80, y: category == .shorts ? 92 : category == .skirt ? 119 : 220)
        }
        let lower = category.garmentKind == .lower
        let height: CGFloat = lower ? 258 : category == .coat ? 235 : 215
        let originY: CGFloat = lower ? -10 : 0
        let scale = min(size.width / 125, size.height / height)
        return CGPoint(
            x: (size.width - 125 * scale) / 2 + point.x * scale,
            y: (size.height - height * scale) / 2 + (point.y - originY) * scale
        )
    }
}
#endif
