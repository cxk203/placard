import ImageIO
import SwiftUI
import UIKit

struct WallpaperGrid: View {
    let wallpapers: [Wallpaper]
    @Namespace private var transitionNamespace
    @State private var selectedWallpaper: Wallpaper?

    private let columns = [GridItem(.adaptive(minimum: 164, maximum: 260), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(wallpapers) { wallpaper in
                Button {
                    selectedWallpaper = wallpaper
                } label: {
                    WallpaperCard(
                        wallpaper: wallpaper,
                        showsAuthor: wallpaper.authors != nil,
                        transitionNamespace: transitionNamespace
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open preview")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fullScreenCover(item: $selectedWallpaper) { wallpaper in
            NavigationStack {
                WallpaperDetailView(
                    wallpaper: wallpaper,
                    showsAuthor: wallpaper.authors != nil,
                    transitionNamespace: transitionNamespace
                )
            }
            .navigationTransition(
                .zoom(sourceID: wallpaper.id, in: transitionNamespace)
            )
        }
    }
}

struct WallpaperLoadingGrid: View {
    private let columns = [GridItem(.adaptive(minimum: 164, maximum: 260), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                WallpaperCard(wallpaper: .placeholder, showsAuthor: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}

struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let showsAuthor: Bool
    var transitionNamespace: Namespace.ID?

    init(
        wallpaper: Wallpaper,
        showsAuthor: Bool,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.wallpaper = wallpaper
        self.showsAuthor = showsAuthor
        self.transitionNamespace = transitionNamespace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteWallpaperPreview(url: wallpaper.previewURL, aspectRatio: 0.72)
                .clipShape(.rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.separator.opacity(0.35), lineWidth: 0.5)
                }
                .modifier(
                    WallpaperTransitionSource(
                        id: wallpaper.id,
                        namespace: transitionNamespace
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(wallpaper.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if showsAuthor {
                    Text(wallpaper.authors ?? "Unknown Author")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(.rect)
    }
}

private struct WallpaperTransitionSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

struct RemoteWallpaperPreview: View {
    let url: URL
    let aspectRatio: CGFloat
    let playback: PreviewPlayback

    init(
        url: URL,
        aspectRatio: CGFloat,
        playback: PreviewPlayback = .thumbnail
    ) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.playback = playback
    }

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    AnimatedImageView(image: image, animates: playback == .animated)
                } else if didFail {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: url) { await load() }
    }

    private func load() async {
        if let cached = AnimatedImageLoader.cached(url, playback: playback) {
            image = cached
            return
        }
        image = nil
        didFail = false
        let loaded = await AnimatedImageLoader.load(url, playback: playback)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            if let loaded {
                image = loaded
            } else {
                didFail = true
            }
        }
    }
}

enum PreviewPlayback: Sendable {
    /// Cheap, downsampled stills for scrolling collections.
    case thumbnail
    /// Full animation is reserved for the single image shown in the detail view.
    case animated
}

/// Displays a (possibly animated) `UIImage`. `UIImageView` loops animated
/// images automatically, which SwiftUI's `Image`/`AsyncImage` do not.
private struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage
    let animates: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = image
        if animates {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

enum AnimatedImageLoader {
    nonisolated private static let cache = ImageCache()
    nonisolated private static let maximumPreviewDataBytes = 20 * 1_024 * 1_024
    nonisolated private static let maximumAnimatedFrames = 60
    nonisolated private static let thumbnailPixelSize = 600
    nonisolated private static let animatedPixelSize = 1_000

    nonisolated static func cached(_ url: URL, playback: PreviewPlayback) -> UIImage? {
        cache.image(for: cacheKey(for: url, playback: playback))
    }

    nonisolated static func load(_ url: URL, playback: PreviewPlayback) async -> UIImage? {
        if let cached = cached(url, playback: playback) { return cached }
        do {
            let data = try await RemoteAssetCache.shared.data(for: url)
            guard data.count <= maximumPreviewDataBytes else { return nil }
            guard !Task.isCancelled else { return nil }
            let image = await Task.detached(priority: .utility) {
                decode(data, playback: playback)
            }.value
            guard let image, !Task.isCancelled else { return nil }
            cache.insert(image, for: cacheKey(for: url, playback: playback), cost: imageCost(image))
            return image
        } catch {
            return nil
        }
    }

    nonisolated private static func cacheKey(for url: URL, playback: PreviewPlayback) -> NSString {
        "\(url.absoluteString)#\(cacheSuffix(for: playback))" as NSString
    }

    nonisolated private static func cacheSuffix(for playback: PreviewPlayback) -> String {
        switch playback {
        case .thumbnail: "thumbnail"
        case .animated: "animated"
        }
    }

    nonisolated private static func isAnimated(_ playback: PreviewPlayback) -> Bool {
        switch playback {
        case .thumbnail: false
        case .animated: true
        }
    }

    nonisolated private static func decode(_ data: Data, playback: PreviewPlayback) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(source)
        guard isAnimated(playback), count > 1 else {
            return thumbnail(source: source, maxPixelSize: thumbnailPixelSize)
        }

        var frames: [UIImage] = []
        var duration = 0.0
        let stride = max(1, Int(ceil(Double(count) / Double(maximumAnimatedFrames))))
        for index in stride(from: 0, to: count, by: stride) {
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                index,
                thumbnailOptions(maxPixelSize: animatedPixelSize)
            ) else { continue }
            duration += frameDelay(source: source, index: index)
            frames.append(UIImage(cgImage: cgImage))
        }
        guard frames.count > 1 else { return thumbnail(source: source, maxPixelSize: thumbnailPixelSize) }
        if duration <= 0 { duration = Double(frames.count) / 30.0 }
        return UIImage.animatedImage(with: frames, duration: duration)
    }

    nonisolated private static func thumbnailOptions(maxPixelSize: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
    }

    nonisolated private static func thumbnail(source: CGImageSource, maxPixelSize: Int) -> UIImage? {
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions(maxPixelSize: maxPixelSize)
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated private static func imageCost(_ image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        let frames = max(1, image.images?.count ?? 1)
        return max(1, width * height * 4 * frames)
    }

    nonisolated private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
            return unclamped
        }
        if let delay = gif[kCGImagePropertyGIFDelayTime] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }
}

nonisolated private final class ImageCache: @unchecked Sendable {
    private let values = NSCache<NSString, UIImage>()

    init() {
        values.countLimit = 120
        values.totalCostLimit = 96 * 1_024 * 1_024
    }

    func image(for key: NSString) -> UIImage? {
        values.object(forKey: key)
    }

    func insert(_ image: UIImage, for key: NSString, cost: Int) {
        values.setObject(image, forKey: key, cost: cost)
    }
}
