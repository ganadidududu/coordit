import Foundation

struct CoorditNarrativeFiber: Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let trait: String
    let caution: String
}

#if os(iOS)
struct CoorditFitLabNarrative {
    struct Component: Equatable {
        let fiberID: String
        let name: String
        let percent: Double
    }
    enum Shape: String { case unknown, boxy, mixed }
    let draft: CoorditFitLabDraft
    private var facts: CoorditProductFacts? { draft.productFacts.flatMap { $0.applies(to: draft) ? $0 : nil } }
    private func fact(_ kind: String) -> String? {
        let values = facts?.items.filter { $0.kind == kind } ?? []
        return values.count == 1 ? values.first?.value : nil
    }
    private func normalized(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.lowercased().replacingOccurrences(of: " ", with: "")
    }
    private func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    var components: [Component] {
        guard let material = fact("material") else { return [] }
        let text = material.precomposedStringWithCompatibilityMapping.lowercased().replacingOccurrences(of: ",", with: ".")
        guard !matches("안감|충전|배색|lining|filling|[-~]\\s*[0-9]|이상|이하|약|approx|less|more", text) else { return [] }
        let patterns = ["([a-z가-힣][a-z가-힣 \\-]*?)\\s*[:：]?\\s*\\(?\\s*([0-9]+(?:\\.[0-9]+)?)\\s*%", "([0-9]+(?:\\.[0-9]+)?)\\s*%\\s*([a-z가-힣][a-z가-힣 \\-]*)"]
        let percentCount = text.filter { $0 == "%" }.count
        guard percentCount > 0 else { return [] }
        for (direction, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            guard matches.count == percentCount else { continue }
            var parsed: [Component] = []
            for match in matches {
                let nameIndex = direction == 0 ? 1 : 2
                let percentIndex = direction == 0 ? 2 : 1
                guard let nameRange = Range(match.range(at: nameIndex), in: text),
                      let percentRange = Range(match.range(at: percentIndex), in: text),
                      let percent = Double(text[percentRange]), (0...100).contains(percent) else { return [] }
                let rawName = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "^(겉감|소재|혼용률|material|composition|recycled|organic|오가닉|유기농|리사이클드|리사이클)\\s*[:：]?\\s*", with: "", options: .regularExpression)
                guard let fiber = CoorditNarrativeRules.fibers.first(where: { $0.aliases.contains { normalized($0) == normalized(rawName) } }),
                      !parsed.contains(where: { $0.fiberID == fiber.id }),
                      fiber.id != "elastane" || percent <= CoorditNarrativeRules.maximumElastanePercent else { return [] }
                parsed.append(.init(fiberID: fiber.id, name: fiber.name, percent: percent))
            }
            let total = parsed.reduce(0) { $0 + $1.percent }
            guard total >= CoorditNarrativeRules.minimumCompositionTotal, total <= CoorditNarrativeRules.maximumCompositionTotal else { return [] }
            return parsed.filter { $0.percent > 0 }.sorted { $0.percent == $1.percent ? $0.fiberID < $1.fiberID : $0.percent > $1.percent }
        }
        return []
    }

    private var ratios: [Double] {
        guard CoorditNarrativeRules.boxyMinimums[draft.category.rawValue] != nil, draft.sizes.count >= 2 else { return [] }
        let values = draft.sizes.compactMap { row -> Double? in
            guard let width = row.measurements[.chestWidth], let length = row.measurements[.totalLength],
                  width.isFinite, length.isFinite,
                  CoorditNarrativeRules.widthBounds.contains(width), CoorditNarrativeRules.lengthBounds.contains(length) else { return nil }
            return width / length
        }
        return values.count == draft.sizes.count ? values : []
    }
    var shape: Shape {
        guard let threshold = CoorditNarrativeRules.boxyMinimums[draft.category.rawValue], !ratios.isEmpty else { return .unknown }
        if ratios.allSatisfy({ $0 >= threshold }) { return .boxy }
        if ratios.contains(where: { $0 >= threshold }) { return .mixed }
        return .unknown
    }
    var stretchConflict: Bool {
        components.contains { $0.fiberID == "elastane" } && fact("stretch").map { matches("없|무신축|non.?stretch|^(no|none)$", $0.lowercased()) } == true
    }
    var fitConflict: Bool { shape == .boxy && fact("fit").map { !matches("아니|아님|않|not|non", $0.lowercased()) && matches("슬림|타이트|slim|tight", $0.lowercased()) } == true }
    var traitIDs: [String] {
        components.filter { component in component.fiberID != "elastane" && component.percent >= CoorditNarrativeRules.minimumTraitPercent && CoorditNarrativeRules.fibers.contains { $0.id == component.fiberID && !$0.trait.isEmpty } }.prefix(2).map(\.fiberID)
    }
    private func render(_ key: String, _ values: [String: String] = [:]) -> String {
        values.reduce(CoorditNarrativeRules.text[key] ?? "") { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
    private func number(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value).replacingOccurrences(of: ".0", with: "")
    }
    var paragraph: String {
        var sentences: [String] = []
        if !traitIDs.isEmpty {
            let blend = components.map { "\($0.name) \(number($0.percent))%" }.joined(separator: "·")
            let selected = traitIDs.compactMap { id in CoorditNarrativeRules.fibers.first { $0.id == id } }
            var orderedTraits: [String] = []
            for fiber in selected where !orderedTraits.contains(fiber.trait) { orderedTraits.append(fiber.trait) }
            let traits = orderedTraits.map { trait in
                selected.filter { $0.trait == trait }.map(\.name).joined(separator: "·") + "의 " + trait
            }.joined(separator: "과 ")
            sentences.append(render("material", ["blend": blend, "traits": traits]))
            if let dominant = components.first, dominant.percent >= 50,
               let caution = CoorditNarrativeRules.fibers.first(where: { $0.id == dominant.fiberID })?.caution, !caution.isEmpty { sentences.append(caution) }
        }
        if let stretch = fact("stretch"), stretch.count <= 24 { sentences.append("신축성은 ‘\(stretch)’으로 표시돼 있어요.") }
        else if !stretchConflict, let spandex = components.first(where: { $0.fiberID == "elastane" && $0.percent >= 1 }) {
            sentences.append(render("stretch", ["percent": number(spandex.percent)]))
        }
        if fitConflict { sentences.append(render("conflict")) }
        else {
            if let fit = fact("fit"), fit.count <= 24 { sentences.append(render("sellerFit", ["value": fit])) }
            switch shape {
            case .boxy:
                if let minimum = ratios.min(), let maximum = ratios.max() {
                    sentences.append(render("boxy", ["count": String(ratios.count), "minimum": number((minimum * 100).rounded()), "maximum": number((maximum * 100).rounded())]))
                }
            case .mixed: sentences.append(render("mixed"))
            case .unknown: break
            }
        }
        return sentences.joined(separator: " ")
    }
}
#endif
