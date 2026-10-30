import XCTest
import UIKit
@testable import coordit

@MainActor
final class CoorditGarmentPhotoTests: XCTestCase {
    func testConfirmedCaptureProducesPhotoAndRetakeClearsIt() throws {
        let capture = CoorditGarmentCaptureController(method: .card)
        capture.loadTestFixture()
        capture.basisConfirmed = true
        _ = try capture.makeMeasurement()
        let data = try XCTUnwrap(capture.garmentPhotoData)
        let photo = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(photo.size.width, photo.size.height), 1200)
        XCTAssertGreaterThan(data.count, 1000)
        capture.clearCapture()
        XCTAssertNil(capture.garmentPhotoData)
    }

    func testPhotoSurvivesStoreRecreationAndIsIsolatedByAccountAndGarment() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoorditGarmentPhotoStore(directory: directory)
        let first = Data("first photo".utf8)
        let replacement = Data("replacement photo".utf8)
        try store.save(first, userID: "a", clothingID: "shirt")
        let reopened = CoorditGarmentPhotoStore(directory: directory)
        XCTAssertEqual(reopened.photo(userID: "a", clothingID: "shirt"), first)
        XCTAssertNil(reopened.photo(userID: "b", clothingID: "shirt"))
        XCTAssertNil(reopened.photo(userID: "a", clothingID: "pants"))
        try reopened.save(replacement, userID: "a", clothingID: "shirt")
        XCTAssertEqual(store.photo(userID: "a", clothingID: "shirt"), replacement)
        try store.save(first, userID: "b", clothingID: "shirt")
        try store.remove(userID: "a", clothingID: "shirt")
        XCTAssertNil(reopened.photo(userID: "a", clothingID: "shirt"))
        XCTAssertEqual(reopened.photo(userID: "b", clothingID: "shirt"), first)
        try store.removeAll(userID: "b")
        XCTAssertNil(reopened.photo(userID: "b", clothingID: "shirt"))
    }
}
