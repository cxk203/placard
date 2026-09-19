import Foundation
import XCTest
@testable import placard

final class CatalogSourceHealthTests: XCTestCase {
    func testStatusStoreKeepsTheLatestStatusForEachSource() async {
        let store = CatalogSourceHealthStore()
        await store.set(CatalogSourceStatus(collection: .lsNguyen, name: "LSNguyen", state: .available))
        await store.set(CatalogSourceStatus(collection: .lsNguyen, name: "LSNguyen", state: .stale))
        let statuses = await store.statuses(for: .lsNguyen)

        XCTAssertEqual(statuses, [CatalogSourceStatus(collection: .lsNguyen, name: "LSNguyen", state: .stale)])
    }

    func testSnapshotStoreRoundTripsValidCatalogData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PlacardSnapshotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CatalogSourceSnapshotStore(directory: directory)
        let url = URL(string: "https://example.invalid/catalog.json")!
        let data = Data("{\"packages\":[]}".utf8)

        try await store.save(data, for: url)
        let loaded = await store.load(for: url)
        XCTAssertEqual(loaded, data)
    }
}
