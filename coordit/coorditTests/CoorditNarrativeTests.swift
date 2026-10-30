import XCTest
@testable import coordit

@MainActor
final class CoorditNarrativeTests: XCTestCase {
    private struct Case: Decodable {
        struct Expected: Decodable {
            let components: [String]
            let traits: [String]
            let shape: String
            let fitConflict: Bool
            let stretchConflict: Bool
        }
        let id: String
        let category: String
        let rows: [[String: Double]]
        let facts: [String: String]
        let edited: Bool
        let expected: Expected
    }

    func testSharedCompositionAndWholeTableDecisions() throws {
        // Given the same independently authored vectors used by Android.
        let path = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "NarrativeCases", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: path))
        let url = try XCTUnwrap(URL(string: "https://shop.example/products/fixture"))
        var rendered: [String: String] = [:]
        for item in cases {
            let category = try XCTUnwrap(CoorditFitLabCategory(rawValue: item.category))
            let rows = item.rows.enumerated().map { index, values in
                CoorditFitLabSizeDraft(label: index == 0 ? "M" : "L", measurements: Dictionary(uniqueKeysWithValues: values.compactMap { key, value in CoorditFitLabMeasurementKey(rawValue: key).map { ($0, value) } }))
            }
            let facts = CoorditProductFacts(productName: "테스트 상품", sourceUrl: url, capturedAt: "2026-10-30T03:00:00.000Z", items: item.facts.sorted { $0.key < $1.key }.map { .init(kind: $0.key, value: $0.value) })
            let draft = CoorditFitLabDraft(source: .url, garmentKind: category.garmentKind, category: category,
                productName: item.edited ? "수정 상품" : "테스트 상품", productURL: url, productFacts: facts, sizes: rows)
            // When a fresh on-device analysis is computed.
            let analysis = CoorditFitLabNarrative(draft: draft)
            // Then only justified semantic decisions are emitted; prose is not pinned.
            XCTAssertEqual(analysis.components.map(\.fiberID), item.expected.components, item.id)
            XCTAssertEqual(analysis.traitIDs, item.expected.traits, item.id)
            XCTAssertEqual(analysis.shape.rawValue, item.expected.shape, item.id)
            XCTAssertEqual(analysis.fitConflict, item.expected.fitConflict, item.id)
            XCTAssertEqual(analysis.stretchConflict, item.expected.stretchConflict, item.id)
            rendered[item.id] = analysis.paragraph
        }
        let attachment = XCTAttachment(data: try JSONEncoder().encode(rendered), uniformTypeIdentifier: "public.json")
        attachment.name = "narrative-parity"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMeasurementEditsRecomputeShapeWithoutChangingSourceFacts() throws {
        // Given two wide/short shirt sizes.
        var draft = CoorditFitLabDraft(garmentKind: .upper, category: .shirt, sizes: [
            .init(label: "M", measurements: [.chestWidth: 56, .totalLength: 70]),
            .init(label: "L", measurements: [.chestWidth: 58, .totalLength: 72])
        ])
        XCTAssertEqual(CoorditFitLabNarrative(draft: draft).shape, .boxy)
        // When the user changes only the two lengths.
        draft.sizes[0].measurements[.totalLength] = 80
        draft.sizes[1].measurements[.totalLength] = 82
        // Then a previous boxy interpretation cannot survive the edit.
        XCTAssertEqual(CoorditFitLabNarrative(draft: draft).shape, .unknown)
    }
}
