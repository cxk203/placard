import CryptoKit
import Foundation
import ZIPFoundation

nonisolated enum WallpaperPackageError: LocalizedError, Equatable, Sendable {
    case passwordProtected
    case missingRequiredFile(String)
    case invalidPropertyList(String)
    case missingReferencedResource(String)
    case checksumMismatch

    nonisolated var errorDescription: String? {
        switch self {
        case .passwordProtected:
            String(localized: "This wallpaper package is password-protected. Extract it without a password before importing.")
        case .missingRequiredFile(let path):
            String(localized: "The wallpaper package is missing a required file: \(path)")
        case .invalidPropertyList(let path):
            String(localized: "The wallpaper package contains an invalid property list: \(path)")
        case .missingReferencedResource(let path):
            String(localized: "The wallpaper package references a missing resource: \(path)")
        case .checksumMismatch:
            String(localized: "The downloaded wallpaper does not match its published SHA-256 checksum.")
        }
    }
}

nonisolated enum WallpaperPackageChecksum {
    nonisolated static func verify(fileURL: URL, expected: String?) throws {
        guard let normalized = normalized(expected) else { return }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 64 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == normalized else { throw WallpaperPackageError.checksumMismatch }
    }

    nonisolated static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count == 64,
              normalized.allSatisfy({ $0.isHexDigit }) else { return nil }
        return normalized
    }
}

nonisolated enum ZIPArchiveInspector {
    private nonisolated static let centralDirectorySignature: [UInt8] = [0x50, 0x4b, 0x01, 0x02]

    nonisolated static func isPasswordProtected(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        let chunkSize = 128 * 1_024
        while true {
            guard let data = try? handle.read(upToCount: chunkSize),
                  !data.isEmpty else { break }
            let bytes = [UInt8](data)
            guard bytes.count >= 10 else { continue }
            for index in 0...(bytes.count - 10) where Array(bytes[index..<(index + 4)]) == centralDirectorySignature {
                let flag = UInt16(bytes[index + 8]) | (UInt16(bytes[index + 9]) << 8)
                if flag & 0x0001 != 0 { return true }
            }
        }
        return false
    }
}

nonisolated enum WallpaperPackageValidator {
    nonisolated static func extract(_ packageURL: URL, into workspace: URL, fileManager: FileManager = .default) throws -> URL {
        guard !ZIPArchiveInspector.isPasswordProtected(at: packageURL) else {
            throw WallpaperPackageError.passwordProtected
        }

        let destination = workspace.appending(path: "Extracted", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        do {
            try fileManager.unzipItem(at: packageURL, to: destination)
        } catch {
            throw InstallError.invalidPackage
        }
        return destination
    }

    nonisolated static func descriptorGroups(in root: URL, fileManager: FileManager = .default) throws -> [String: [URL]] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else { throw InstallError.invalidPackage }

        var groups: [String: [URL]] = [:]
        for case let directory as URL in enumerator {
            let values = try directory.resourceValues(forKeys: Set(resourceKeys))
            guard values.isDirectory == true else { continue }
            if directory.lastPathComponent == "__MACOSX" {
                enumerator.skipDescendants()
                continue
            }

            let name = directory.lastPathComponent.lowercased()
            let extensionID: String?
            if name == "descriptors",
               let extensionsIndex = directory.pathComponents.lastIndex(of: "Extensions"),
               directory.pathComponents.indices.contains(extensionsIndex + 1) {
                extensionID = directory.pathComponents[extensionsIndex + 1]
            } else if ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"].contains(name) {
                extensionID = "com.apple.WallpaperKit.CollectionsPoster"
            } else if ["video-descriptor", "video-descriptors"].contains(name) {
                extensionID = "com.apple.PhotosUIPrivate.PhotosPosterProvider"
            } else {
                extensionID = nil
            }

            guard let extensionID else { continue }
            let children = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && $0.lastPathComponent != "__MACOSX"
            }
            for descriptor in children {
                try validate(descriptor: descriptor, extensionID: extensionID, fileManager: fileManager)
            }
            if !children.isEmpty { groups[extensionID, default: []].append(contentsOf: children) }
            enumerator.skipDescendants()
        }

        guard !groups.isEmpty else { throw InstallError.noDescriptors }
        return groups
    }

    nonisolated private static func validate(descriptor: URL, extensionID: String, fileManager: FileManager) throws {
        let role = descriptor.appending(path: "com.apple.posterkit.role.identifier")
        let identifier = descriptor.appending(path: "com.apple.posterkit.provider.descriptor.identifier")
        let contents = descriptor.appending(path: "versions/1/contents", directoryHint: .isDirectory)
        for url in [role, identifier, contents] where !fileManager.fileExists(atPath: url.path) {
            throw WallpaperPackageError.missingRequiredFile(url.lastPathComponent)
        }

        let roleValue = try String(contentsOf: role, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roleValue.isEmpty else { throw WallpaperPackageError.missingRequiredFile(role.lastPathComponent) }
        let identifierValue = try String(contentsOf: identifier, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard Int(identifierValue) != nil else { throw WallpaperPackageError.invalidPropertyList(identifier.lastPathComponent) }

        let plists = try wallpaperPlists(in: contents, fileManager: fileManager)
        if extensionID == "com.apple.WallpaperKit.CollectionsPoster", plists.isEmpty {
            throw WallpaperPackageError.missingRequiredFile("Wallpaper.plist")
        }
        for plist in plists { try validateWallpaperPlist(plist, fileManager: fileManager) }
    }

    nonisolated private static func wallpaperPlists(in contents: URL, fileManager: FileManager) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: contents,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { throw InstallError.invalidPackage }
        return enumerator.compactMap { $0 as? URL }.filter { $0.lastPathComponent == "Wallpaper.plist" }
    }

    nonisolated private static func validateWallpaperPlist(_ url: URL, fileManager: FileManager) throws {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.binary
        let parsed = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        )
        guard let plist = parsed as? [String: Any] else {
            throw WallpaperPackageError.invalidPropertyList(url.path)
        }
        guard let assets = plist["assets"] as? [String: Any] else {
            throw WallpaperPackageError.invalidPropertyList(url.path)
        }
        let references = animationReferences(in: assets)
        let parent = url.deletingLastPathComponent()
        for reference in references {
            let resource = parent.appending(path: reference, directoryHint: .isDirectory)
            guard fileManager.fileExists(atPath: resource.path) else {
                throw WallpaperPackageError.missingReferencedResource(resource.lastPathComponent)
            }
        }
    }

    nonisolated private static func animationReferences(in value: Any) -> Set<String> {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: Set<String>()) { result, item in
                if item.key.localizedCaseInsensitiveContains("AnimationFileName"),
                   let name = item.value as? String, name.hasSuffix(".ca") {
                    result.insert(name)
                }
                result.formUnion(animationReferences(in: item.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: Set<String>()) { $0.formUnion(animationReferences(in: $1)) }
        }
        return []
    }
}
