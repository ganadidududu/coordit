import Foundation

#if os(iOS)
struct CoorditFitLabProductSummary {
    struct Measurement: Identifiable {
        let key: CoorditFitLabMeasurementKey
        let minimum: Double
        let maximum: Double
        let sizeCount: Int
        var id: CoorditFitLabMeasurementKey { key }
    }

    let measurements: [Measurement]
    let hasMissingMeasurements: Bool

    init(draft: CoorditFitLabDraft) {
        let keys: [CoorditFitLabMeasurementKey]
        if draft.category == .skirt {
            let hasTotalLength = draft.sizes.contains {
                guard let value = $0.measurements[.totalLength] else { return false }
                return value.isFinite && value > 0
            }
            keys = [.waistWidth, .hipWidth, hasTotalLength ? .totalLength : .outseam]
        } else {
            keys = CoorditFitLabMeasurementKey.allCases.filter { $0.garmentKind == draft.garmentKind }
        }
        measurements = keys.compactMap { key in
            let values = draft.sizes.compactMap { $0.measurements[key] }.filter { $0.isFinite && $0 > 0 }
            guard let minimum = values.min(), let maximum = values.max() else { return nil }
            return Measurement(key: key, minimum: minimum, maximum: maximum, sizeCount: values.count)
        }
        hasMissingMeasurements = draft.sizes.isEmpty || keys.contains { key in
            draft.sizes.contains { size in
                guard let value = size.measurements[key] else { return true }
                return !value.isFinite || value <= 0
            }
        }
    }
}
#endif
