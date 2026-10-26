import CryptoKit
import Foundation

struct CoorditGarmentPhotoStore {
    static let shared = CoorditGarmentPhotoStore(directory: URL.applicationSupportDirectory.appending(path: "GarmentPhotos", directoryHint: .isDirectory))
    let directory: URL

    func save(_ data: Data, userID: String, clothingID: String) throws {
        let url = photoURL(userID: userID, clothingID: clothingID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func photo(userID: String, clothingID: String) -> Data? {
        try? Data(contentsOf: photoURL(userID: userID, clothingID: clothingID))
    }

    func remove(userID: String, clothingID: String) throws {
        let url = photoURL(userID: userID, clothingID: clothingID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func photoURL(userID: String, clothingID: String) -> URL {
        directory.appending(path: digest(userID), directoryHint: .isDirectory)
            .appending(path: digest(clothingID) + ".jpg")
    }

    func removeAll(userID: String) throws {
        let url = directory.appending(path: digest(userID), directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
