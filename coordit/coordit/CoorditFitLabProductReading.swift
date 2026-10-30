import Foundation

#if os(iOS)
struct CoorditFitLabProductReading {
    let draft: CoorditFitLabDraft

    private var widthKey: CoorditFitLabMeasurementKey { draft.garmentKind == .upper ? .chestWidth : .waistWidth }
    private var lengthKey: CoorditFitLabMeasurementKey {
        if draft.garmentKind == .upper { return .totalLength }
        if draft.category == .skirt, draft.sizes.contains(where: {
            guard let value = $0.measurements[.totalLength] else { return false }
            return value.isFinite && value > 0
        }) { return .totalLength }
        return .outseam
    }
    private var widthName: String { draft.garmentKind == .upper ? "가슴" : "허리" }

    private var comparisonPair: (first: CoorditFitLabSizeDraft, other: CoorditFitLabSizeDraft)? {
        let pairs = zip(draft.sizes, draft.sizes.dropFirst())
        return pairs.max { left, right in
            let leftWidth = abs(difference(widthKey, from: left.0, to: left.1) ?? 0)
            let rightWidth = abs(difference(widthKey, from: right.0, to: right.1) ?? 0)
            if leftWidth != rightWidth { return leftWidth < rightWidth }
            return abs(difference(lengthKey, from: left.0, to: left.1) ?? 0)
                < abs(difference(lengthKey, from: right.0, to: right.1) ?? 0)
        }.map { (first: $0.0, other: $0.1) }
    }

    var conciseSizeSummary: String {
        let summary = CoorditFitLabProductSummary(draft: draft)
        let ranges = [(widthKey, "\(widthName) 단면"), (lengthKey, "총장")].compactMap { key, name -> String? in
            guard let item = summary.measurements.first(where: { $0.key == key }) else { return nil }
            let range = item.minimum == item.maximum ? number(item.minimum) : "\(number(item.minimum))–\(number(item.maximum))"
            return "\(name) \(range)cm"
        }
        let labels = draft.sizes.count <= 4 ? draft.sizes.map(\.label).joined(separator: ", ") : "사이즈 \(draft.sizes.count)개"
        let overview = ([labels] + ranges).filter { !$0.isEmpty }.joined(separator: " · ")
        guard let pair = comparisonPair else { return overview }
        let changes = [(widthKey, "\(widthName) 단면"), (lengthKey, "총장")].compactMap { key, name -> String? in
            guard let change = difference(key, from: pair.first, to: pair.other) else { return nil }
            return "\(name) \(change > 0 ? "+" : "")\(number(change))cm"
        }
        guard !changes.isEmpty else { return overview }
        return overview + "\n\(pair.first.label) → \(pair.other.label): " + changes.joined(separator: " · ")
    }

    var headline: String {
        if let pair = comparisonPair {
            if let width = difference(widthKey, from: pair.first, to: pair.other) {
                if abs(width) >= 0.05 {
                    return "\(pair.first.label)보다 \(pair.other.label)의 \(widthName) 단면이 \(number(abs(width)))cm \(width > 0 ? "넓어요" : "좁아요")."
                }
                return "두 사이즈의 \(widthName) 너비는 같아요."
            }
            if let length = difference(lengthKey, from: pair.first, to: pair.other), abs(length) >= 0.05 {
                return "두 사이즈의 기장은 \(number(abs(length)))cm 차이가 나요."
            }
        }
        if draft.sizes.count == 1 { return "이 상품은 한 가지 사이즈로 나와요." }
        return "상품에 표시된 실측을 확인해주세요."
    }

    var headlineDetail: String {
        guard let pair = comparisonPair else {
            return "평소 잘 맞는 옷의 너비와 길이를 기준으로 보면 고르기 쉬워요."
        }
        let prefix = "\(pair.first.label)에서 \(pair.other.label)로 바꿀 때의 차이예요."
        guard let width = difference(widthKey, from: pair.first, to: pair.other),
              let length = difference(lengthKey, from: pair.first, to: pair.other) else {
            return "\(prefix) 확인된 치수부터 비교했어요. 비어 있는 항목은 아래 실측표에서 확인해주세요."
        }
        if abs(width) < 0.05, abs(length) >= 0.05 {
            return "\(prefix) 기장은 달라져도 \(widthName) 쪽 여유는 같아요. 더 넉넉하게 입으려고 사이즈를 바꾼다면 이 부분을 먼저 보세요."
        }
        if abs(width) >= 0.05, abs(length) < 0.05 {
            return "\(prefix) 기장은 그대로이고 품만 달라져요. 길이보다 \(widthName) 쪽 여유를 기준으로 골라보세요."
        }
        if width * length < 0 {
            return "\(prefix) 너비와 길이가 반대로 달라져요. 큰 사이즈가 모든 부위에서 더 큰 건 아니니 두 치수를 같이 봐주세요."
        }
        if abs(width) < 0.05, abs(length) < 0.05 {
            return "\(prefix) \(widthName) 너비와 총장이 같아요. 다른 부위의 치수나 상품 옵션이 다른지 확인해주세요."
        }
        return "\(prefix) 품과 기장이 함께 달라져요. 원하는 여유뿐 아니라 밑단이 어디까지 내려올지도 같이 봐주세요."
    }

    var overview: String {
        let labels = draft.sizes.map(\.label).joined(separator: ", ")
        let sizes = draft.sizes.count == 1 ? "사이즈는 \(labels) 한 가지예요." : "\(labels) 사이즈가 있어요."
        let summary = CoorditFitLabProductSummary(draft: draft)
        let widthKey: CoorditFitLabMeasurementKey = draft.garmentKind == .upper ? .chestWidth : .waistWidth
        let widthName = draft.garmentKind == .upper ? "가슴" : "허리"
        guard let width = summary.measurements.first(where: { $0.key == widthKey }) else {
            return "\(sizes) \(widthName) 치수는 빠져 있어서, 이 부분은 상품 페이지에서 한 번 더 확인해주세요."
        }
        let range = width.minimum == width.maximum ? number(width.minimum) : "\(number(width.minimum))~\(number(width.maximum))"
        return "\(sizes) \(widthName) 단면은 \(range)cm로 나와 있어요. 평소 입는 사이즈와 이름이 같아도 실제 크기는 다를 수 있어요."
    }

    var sizeDifferenceTitle: String {
        guard let pair = comparisonPair else { return "사이즈 고를 때" }
        return "\(pair.first.label) → \(pair.other.label) 차이"
    }

    var sizeDifference: String {
        guard let pair = comparisonPair else {
            return "다른 사이즈가 없어 크기 차이를 비교하긴 어려워요. 평소 잘 맞는 옷을 펼쳐 놓고 너비와 길이를 재보면 고르기 한결 수월해요."
        }
        let first = pair.first
        let other = pair.other
        let widthKey: CoorditFitLabMeasurementKey = draft.garmentKind == .upper ? .chestWidth : .waistWidth
        let widthName = draft.garmentKind == .upper ? "가슴" : "허리"
        var sentences: [String] = []
        if let change = difference(widthKey, from: first, to: other) {
            if abs(change) < 0.05 {
                sentences.append("사이즈 이름은 다르지만 \(widthName) 단면은 같아요. 이 부분의 여유는 비슷하다고 보면 돼요.")
            } else {
                let direction = change > 0 ? "넓어요" : "좁아요"
                let feeling = change > 0 ? "\(widthName) 쪽 여유가 더 있어요" : "\(widthName) 쪽이 더 타이트해요"
                sentences.append("\(first.label)보다 \(other.label)의 \(widthName) 단면이 \(number(abs(change)))cm 더 \(direction). 둘레로는 약 \(number(abs(change) * 2))cm 차이가 나서 \(feeling).")
            }
        }
        if let change = difference(lengthKey, from: first, to: other), abs(change) >= 0.05 {
            let direction = change > 0 ? "길어요" : "짧아요"
            let subject = sentences.isEmpty ? "\(first.label)보다 \(other.label)의 총장이" : "총장은"
            sentences.append("\(subject) \(number(abs(change)))cm 더 \(direction).")
        }
        if sentences.isEmpty {
            return "두 사이즈에 공통으로 적힌 치수가 부족해 크기 차이를 비교하기 어려워요. 아래 실측표에 나온 부분부터 확인해주세요."
        }
        return sentences.joined(separator: " ")
    }

    var wearingContext: String {
        switch draft.category {
        case .tshirt:
            "티셔츠는 가슴과 어깨를 같이 보세요. 어깨선이 내려오는 디자인은 수치가 커도 자연스럽게 떨어지는 편이에요. 기장이 짧고 품이 넓으면 더 박시해 보이고요."
        case .shirt:
            "셔츠는 단추를 잠갔을 때 가슴이 당기지 않는지가 중요해요. 티셔츠 위에 걸쳐 입을 거라면 그만큼 여유를 남겨주세요. 품이 넓어도 어깨와 소매가 맞으면 덜 커 보여요."
        case .sweatshirt:
            "밑단에 시보리가 있는 맨투맨은 옷자락이 모이면서 볼륨이 생겨요. 그래서 품이 넓어도 마냥 큰 옷처럼 보이진 않아요. 가슴 너비와 총장을 같이 봐주세요."
        case .hoodie:
            "후드는 안에 입을 옷까지 생각해서 골라주세요. 기모나 안감이 두꺼우면 같은 치수라도 안쪽은 더 꽉 차요. 후드와 내려오는 어깨선 때문에 상체가 더 커 보이기도 해요."
        case .knit:
            "니트는 짜임과 신축성에 따라 몸에 붙기도, 느슨하게 떨어지기도 해요. 같은 치수라도 느낌이 꽤 달라서 소재 설명을 같이 보는 게 좋아요. 어깨가 부드럽게 내려오면 수치보다 덜 커 보이고요."
        case .jacket:
            "재킷은 품보다 어깨선이 먼저 눈에 들어와요. 어깨 패드가 있으면 실측이 비슷해도 더 각지고 커 보이는 편이에요. 안에 두꺼운 옷을 입을 거라면 가슴과 소매 여유도 챙겨주세요."
        case .coat:
            "코트는 안에 뭘 입을지부터 생각해보세요. 니트나 재킷 위에 입으면 그만큼 안쪽 여유가 줄어요. 품이 비슷해도 기장이 길면 전체적으로 더 커 보일 수 있어요."
        case .pants:
            "팬츠는 허리가 맞아도 앉았을 때 엉덩이나 밑위가 불편할 수 있어요. 세 치수를 함께 봐주세요. 밴딩 허리라면 표에 적힌 수치가 늘리기 전인지도 확인하는 게 좋아요."
        case .jeans:
            "데님은 신축성부터 확인해주세요. 잘 늘어나지 않는 원단이면 같은 허리·엉덩이 치수도 더 타이트하게 느껴져요. 입다 보면 늘어나겠지 하고 작은 사이즈를 고르는 건 피하는 게 좋아요."
        case .shorts:
            "반바지는 허리를 어디까지 올려 입느냐에 따라 보이는 기장이 달라져요. 밑위와 총장을 같이 보세요. 기장이 짧고 통이 넓으면 실제 너비보다 더 여유로워 보이는 편이에요."
        case .skirt:
            "스커트는 허리 위치와 엉덩이 여유를 같이 봐주세요. 일자 디자인은 엉덩이 쪽이 붙기 쉽고, 퍼지는 디자인은 같은 허리 치수라도 더 넉넉해 보여요."
        }
    }

    private func difference(_ key: CoorditFitLabMeasurementKey, from first: CoorditFitLabSizeDraft, to other: CoorditFitLabSizeDraft) -> Double? {
        guard let a = first.measurements[key], let b = other.measurements[key],
              a.isFinite, b.isFinite, a > 0, b > 0 else { return nil }
        return b - a
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
#endif
