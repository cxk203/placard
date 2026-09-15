import Foundation

enum WallpaperCollection: String, CaseIterable, Identifiable, Sendable {
    case caPlayground
    case nugget
    case apple
    case lsNguyen

    var id: Self { self }

    var title: String {
        switch self {
        case .caPlayground: "CAP"
        case .nugget: "Nugget"
        case .apple: "Apple"
        case .lsNguyen: "Plus"
        }
    }
}

enum WallpaperSource: String, Codable, Sendable {
    case nugget
    case caPlayground
    case lsNguyen

    nonisolated var assetBaseURL: URL {
        switch self {
        case .nugget: WallpaperCatalog.nuggetAssetBaseURL
        case .caPlayground: WallpaperCatalog.caPlaygroundAssetBaseURL
        case .lsNguyen: WallpaperCatalog.lsNguyenAssetBaseURL
        }
    }

    nonisolated var packageBaseURL: URL {
        switch self {
        case .nugget: WallpaperCatalog.nuggetPackageBaseURL
        case .caPlayground: WallpaperCatalog.caPlaygroundPackageBaseURL
        case .lsNguyen: WallpaperCatalog.lsNguyenPackageBaseURL
        }
    }
}

enum WallpaperSortOrder: String, CaseIterable, Identifiable, Sendable {
    case random
    case newest
    case oldest

    var id: Self { self }

    var title: String {
        switch self {
        case .random: String(localized: "Random")
        case .newest: String(localized: "Newest")
        case .oldest: String(localized: "Oldest")
        }
    }

    var symbol: String {
        switch self {
        case .random: "shuffle"
        case .newest: "arrow.up"
        case .oldest: "arrow.down"
        }
    }

    /// Reorders the catalog (as-fetched: oldest first) to match this option.
    func apply(to wallpapers: [Wallpaper]) -> [Wallpaper] {
        switch self {
        case .random: wallpapers.shuffled()
        case .newest: wallpapers.reversed()
        case .oldest: wallpapers
        }
    }
}

struct Wallpaper: Codable, Identifiable, Equatable, Sendable {
    let remoteID: Int?
    let name: String
    let description: String?
    let url: String
    let preview: String
    let authors: String?
    let contest: String?
    let source: WallpaperSource

    var id: String { "\(source.rawValue):\(url)" }
    nonisolated var downloadURL: URL {
        if url.hasPrefix("http://") || url.hasPrefix("https://"), let u = URL(string: url) {
            return u
        }
        return source.packageBaseURL.appending(path: url)
    }
    nonisolated var previewURL: URL {
        if preview.hasPrefix("http://") || preview.hasPrefix("https://"), let u = URL(string: preview) {
            return u
        }
        return source.assetBaseURL.appending(path: preview)
    }

    enum CodingKeys: String, CodingKey {
        case remoteID = "id"
        case name, description, url, preview, authors, contest, source
    }

    nonisolated init(
        remoteID: Int?,
        name: String,
        description: String?,
        url: String,
        preview: String,
        authors: String?,
        contest: String?,
        source: WallpaperSource
    ) {
        self.remoteID = remoteID
        self.name = name
        self.description = description
        self.url = url
        self.preview = preview
        self.authors = authors
        self.contest = contest
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remoteID = try container.decodeIfPresent(Int.self, forKey: .remoteID)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decode(String.self, forKey: .url)
        preview = try container.decode(String.self, forKey: .preview)
        authors = try container.decodeIfPresent(String.self, forKey: .authors)
        contest = try container.decodeIfPresent(String.self, forKey: .contest)
        source = try container.decodeIfPresent(WallpaperSource.self, forKey: .source) ?? .nugget
    }

    nonisolated static let placeholder = Wallpaper(
        remoteID: nil,
        name: "Wallpaper",
        description: nil,
        url: "placeholder.tendies",
        preview: "placeholder.png",
        authors: "Author",
        contest: nil,
        source: .nugget
    )

    nonisolated static let previewFixture = Wallpaper(
        remoteID: 1,
        name: "Cipher",
        description: "Decoding…",
        url: "wallpapers/custom/Cipher.tendies",
        preview: "previews/custom/gifs/Cipher.gif",
        authors: "@mightycooldude12",
        contest: "🏆 1st Place",
        source: .nugget
    )
}

extension Array where Element == Wallpaper {
    func deduplicated(excluding: Set<String> = []) -> [Wallpaper] {
        var seen = excluding
        return filter { wallpaper in
            let key = wallpaper.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return true }
            return seen.insert(key).inserted
        }
    }
}

struct WallpaperCatalog: Sendable {
    nonisolated static let nuggetAssetBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/SerStars/nugget-wallpapers/main/")!
    nonisolated static let nuggetPackageBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/SerStars/nugget-wallpapers/main/")!
    nonisolated static let caPlaygroundAssetBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/CAPlayground/wallpapers/main/")!
    nonisolated static let caPlaygroundPackageBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/CAPlayground/wallpapers/main/")!
    nonisolated static let lsNguyenAssetBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/nguyenls3005-cell/LSNguyen-repo/main/")!
    nonisolated static let lsNguyenPackageBaseURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/nguyenls3005-cell/LSNguyen-repo/main/")!
    nonisolated static let spygRepoURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/SpyGdev/3105-repo/refs/heads/main/repositories/purple/repo.json")!
    nonisolated static let denrindzRepoURL = URL(string: "https://ghfast.top/https://raw.githubusercontent.com/tnt300709-debug/-my-3105-repo/main/repo.json")!
    nonisolated static let denrindzBaseString = "https://ghfast.top/https://raw.githubusercontent.com/tnt300709-debug/-my-3105-repo/main/"

    var fetch: @Sendable (WallpaperCollection, CatalogFetchPolicy) async throws -> [Wallpaper]

    static let live = WallpaperCatalog { collection, policy in
        let refresh = policy == .refresh
        switch collection {
        case .nugget:
            let data = try await RemoteAssetCache.shared.data(
                for: nuggetAssetBaseURL.appending(path: "wallpapers-custom.json"),
                refresh: refresh
            )
            let wallpapers = try JSONDecoder().decode([Wallpaper].self, from: data)
            return wallpapers.deduplicated()

        case .apple:
            let data = try await RemoteAssetCache.shared.data(
                for: nuggetAssetBaseURL.appending(path: "wallpapers-apple.json"),
                refresh: refresh
            )
            return try JSONDecoder().decode([Wallpaper].self, from: data)

        case .caPlayground:
            let data = try await RemoteAssetCache.shared.data(
                for: caPlaygroundAssetBaseURL.appending(path: "wallpapers.json"),
                refresh: refresh
            )
            let response = try JSONDecoder().decode(CAPlaygroundCatalogResponse.self, from: data)
            return response.wallpapers
                .sorted { $0.date < $1.date }
                .map(\.wallpaper)
                .deduplicated()

        case .lsNguyen:
            // Dynamic set of names already present in Apple, Nugget, and CAP to exclude duplicates!
            var excludeNames: Set<String> = []
            if let capData = try? await RemoteAssetCache.shared.data(for: caPlaygroundAssetBaseURL.appending(path: "wallpapers.json"), refresh: false),
               let capResp = try? JSONDecoder().decode(CAPlaygroundCatalogResponse.self, from: capData) {
                excludeNames.formUnion(capResp.wallpapers.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            }
            if let nuggetData = try? await RemoteAssetCache.shared.data(for: nuggetAssetBaseURL.appending(path: "wallpapers-custom.json"), refresh: false),
               let nuggetResp = try? JSONDecoder().decode([Wallpaper].self, from: nuggetData) {
                excludeNames.formUnion(nuggetResp.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            }
            if let appleData = try? await RemoteAssetCache.shared.data(for: nuggetAssetBaseURL.appending(path: "wallpapers-apple.json"), refresh: false),
               let appleResp = try? JSONDecoder().decode([Wallpaper].self, from: appleData) {
                excludeNames.formUnion(appleResp.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            }

            var communityWallpapers: [Wallpaper] = []

            // 1. LSNguyen repo
            if let data = try? await RemoteAssetCache.shared.data(for: lsNguyenAssetBaseURL.appending(path: "repo.json"), refresh: refresh),
               let resp = try? JSONDecoder().decode(LSNguyenRepoResponse.self, from: data) {
                communityWallpapers.append(contentsOf: resp.packages.compactMap { $0.wallpaper() })
            }

            // 2. SpyG repo (Foreign creator exclusive wallpapers)
            if let data = try? await RemoteAssetCache.shared.data(for: spygRepoURL, refresh: refresh),
               let resp = try? JSONDecoder().decode(LSNguyenRepoResponse.self, from: data) {
                communityWallpapers.append(contentsOf: resp.packages.compactMap { $0.wallpaper() })
            }

            // 3. Denrindz repo (Community popular wallpapers)
            if let data = try? await RemoteAssetCache.shared.data(for: denrindzRepoURL, refresh: refresh),
               let resp = try? JSONDecoder().decode(LSNguyenRepoResponse.self, from: data) {
                communityWallpapers.append(contentsOf: resp.packages.compactMap { $0.wallpaper(baseURL: denrindzBaseString) })
            }

            return communityWallpapers.deduplicated(excluding: excludeNames)
        }
    }

    static let preview = WallpaperCatalog { _, _ in
        let second = Wallpaper(
            remoteID: 2,
            name: "Rolling Hills",
            description: "boink boink boink",
            url: "wallpapers/custom/RollingHills.tendies",
            preview: "previews/custom/gifs/RollingHills.gif",
            authors: "@i.mes",
            contest: nil,
            source: .nugget
        )
        return [.previewFixture, second]
    }

    static let failingPreview = WallpaperCatalog { _, _ in
        throw CatalogError.invalidResponse
    }
}

private struct LSNguyenRepoResponse: Decodable {
    let packages: [LSNguyenPackage]
}

private struct LSNguyenPackage: Decodable {
    let identifier: String?
    let kind: String?
    let name: String
    let author: String?
    let summary: String?
    let description: String?
    let icon: String?
    let download: String?

    func wallpaper(baseURL: String? = nil) -> Wallpaper? {
        guard kind == "wallpaper" || (download?.hasSuffix(".tendies") == true),
              let download else { return nil }
        let finalDownload: String
        if download.hasPrefix("http://") || download.hasPrefix("https://") {
            finalDownload = download
        } else if let baseURL {
            finalDownload = baseURL + download
        } else {
            finalDownload = download
        }

        let finalIcon: String
        if let icon, !icon.isEmpty {
            if icon.hasPrefix("http://") || icon.hasPrefix("https://") {
                finalIcon = icon
            } else if let baseURL {
                finalIcon = baseURL + icon
            } else {
                finalIcon = icon
            }
        } else {
            finalIcon = ""
        }

        return Wallpaper(
            remoteID: nil,
            name: name,
            description: description ?? summary,
            url: finalDownload,
            preview: finalIcon,
            authors: author,
            contest: nil,
            source: .lsNguyen
        )
    }
}

private struct CAPlaygroundCatalogResponse: Decodable {
    let wallpapers: [CAPlaygroundWallpaper]
}

private struct CAPlaygroundWallpaper: Decodable {
    let name: String
    let creator: String?
    let description: String?
    let file: String
    let preview: String
    let date: Int64

    nonisolated var wallpaper: Wallpaper {
        Wallpaper(
            remoteID: nil,
            name: name,
            description: description,
            url: file,
            preview: preview,
            authors: creator,
            contest: nil,
            source: .caPlayground
        )
    }
}

enum CatalogFetchPolicy: Sendable {
    case cached
    case refresh
}

/// A persistent cache for the catalog and its preview assets. The upstream
/// files are effectively immutable, so normal browsing only goes to the
/// network after URLCache has evicted an item. Explicit refreshes bypass the
/// cached catalog response and replace it after a successful request.
actor RemoteAssetCache {
    nonisolated static let shared = RemoteAssetCache()

    private let cache: URLCache
    private let session: URLSession
    private var inFlight: [URL: Task<Data, Error>] = [:]
    private var activeDownloads = 0
    private var downloadWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appending(path: "PlacardRemoteAssets", directoryHint: .isDirectory)
        let cache = URLCache(
            memoryCapacity: 128 * 1_024 * 1_024,
            diskCapacity: 1024 * 1_024 * 1_024,
            directory: cacheDirectory
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 12
        self.cache = cache
        self.session = URLSession(configuration: configuration)
    }

    func data(for url: URL, refresh: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        if !refresh, let cached = cache.cachedResponse(for: request) {
            return cached.data
        }
        if let task = inFlight[url] {
            return try await task.value
        }

        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = Task<Data, Error> {
            try await self.download(request)
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }

    private func download(_ request: URLRequest) async throws -> Data {
        await acquireDownloadSlot()
        defer { releaseDownloadSlot() }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw CatalogError.invalidResponse
        }
        cache.storeCachedResponse(
            CachedURLResponse(
                response: response,
                data: data,
                storagePolicy: .allowed
            ),
            for: request
        )
        return data
    }

    private func acquireDownloadSlot() async {
        guard activeDownloads >= 10 else {
            activeDownloads += 1
            return
        }
        await withCheckedContinuation { continuation in
            downloadWaiters.append(continuation)
        }
    }

    private func releaseDownloadSlot() {
        guard !downloadWaiters.isEmpty else {
            activeDownloads -= 1
            return
        }
        downloadWaiters.removeFirst().resume()
    }
}

enum CatalogError: LocalizedError {
    case invalidResponse

    var errorDescription: String? { String(localized: "Wallpapers are currently unavailable. Please try again later.") }
}
