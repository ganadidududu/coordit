import SwiftUI

#if os(iOS)
struct CoorditResponsiveMetrics {
    static let designWidth: CGFloat = 402

    let size: CGSize
    let scale: CGFloat

    init(size: CGSize) {
        self.size = size
        scale = max(size.width / Self.designWidth, 0.1)
    }

    func value(_ designValue: CGFloat) -> CGFloat {
        designValue * scale
    }
}
#endif
