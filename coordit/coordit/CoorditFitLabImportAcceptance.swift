#if os(iOS)
import Foundation

enum CoorditFitLabImportAcceptance {
    static func canContinue(sizes: [CoorditFitLabSizeDraft], kind: CoorditFitLabGarmentKind) -> Bool {
        guard !sizes.isEmpty, CoorditFitLabDraftValidation.duplicateSizeLabels(in: sizes.map(\.label)).isEmpty else { return false }
        let dimensions = kind == .upper ? CoorditGarmentDimension.upper : CoorditGarmentDimension.lower
        return sizes.allSatisfy { size in
            !size.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dimensions.allSatisfy { dimension in
                guard let key = CoorditFitLabMeasurementKey(rawValue: dimension.measurementKey),
                      let value = size.measurements[key] else { return false }
                return value.isFinite && dimension.validRange.contains(value)
            }
        }
    }
}
#endif
