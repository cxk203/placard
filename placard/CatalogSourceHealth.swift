import CryptoKit
import Foundation

nonisolated enum CatalogSourceState: Equatable, Sendable {
    case available
    case stale
    case unavailable(String)

    nonisolated var message: String? {
        switch self {
        case .available: nil
        case .stale: String(localized: "Showing the last successful catalog because this source could not be refreshed.")
        case .unavailable(let message): message
        }
    }
}

nonisolated struct CatalogSourceStatus: Identifiable, Equatable, Sendable {
    let collection: WallpaperCollection
    let name: String
    let state: CatalogSourceState

    nonisolated var id: String { "\(collection.rawValue)-\(name)" }
    nonisolated var needsAttention: Bool {
        switch state {
        case .available: false
        case .stale, .unavailable: true
        }
    }
}

actor CatalogSourceHealthStore {
    nonisolated static let shared = CatalogSourceHealthStore()
    private var statuses: [WallpaperCollection: [String: CatalogSourceStatus]] = [:]

    func set(_ status: CatalogSourceStatus) {
        statuses[status.collection, default: [:]][status.name] = status
    }

    func statuses(for collection: WallpaperCollection) -> [CatalogSourceStatus] {
        statuses[collection, default: [:]].values.sorted { $0.name < $1.name }
    }
}

actor CatalogSourceSnapshotStore {
    nonisolated static let shared = CatalogSourceSnapshotStore()

    private let directory: URL

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.directory = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "PlacardCatalogSnapshots", directoryHint: .isDirectory)
    }

    func save(_ data: Data, for url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(for: url), options: .atomic)
    }

    func load(for url: URL) -> Data? {
        try? Data(contentsOf: fileURL(for: url))
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appending(path: "\(digest).json")
    }
}
