import CryptoKit
import Foundation
import XCTest
@testable import placard

final class WallpaperPackageValidatorTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory
            .appending(path: "PlacardTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: workspace)
    }

    func testValidCollectionsDescriptorIsAccepted() throws {
        let root = try makeDescriptor(includeWallpaper: true, includeAnimation: true)
        let groups = try WallpaperPackageValidator.descriptorGroups(in: root)
        XCTAssertEqual(groups["com.apple.WallpaperKit.CollectionsPoster"]?.count, 1)
    }

    func testCollectionsDescriptorWithoutWallpaperPlistIsRejected() throws {
        let root = try makeDescriptor(includeWallpaper: false, includeAnimation: true)
        XCTAssertThrowsError(try WallpaperPackageValidator.descriptorGroups(in: root)) { error in
            XCTAssertEqual(error as? WallpaperPackageError, .missingRequiredFile("Wallpaper.plist"))
        }
    }

    func testMissingAnimationDirectoryIsRejected() throws {
        let root = try makeDescriptor(includeWallpaper: true, includeAnimation: false)
        XCTAssertThrowsError(try WallpaperPackageValidator.descriptorGroups(in: root)) { error in
            guard case WallpaperPackageError.missingReferencedResource = error else {
                return XCTFail("Expected a missing resource error, got \(error)")
            }
        }
    }

    func testChecksumVerificationAcceptsMatchingDigestAndRejectsMismatch() throws {
        let file = workspace.appending(path: "wallpaper.tendies")
        let data = Data("Placard".utf8)
        try data.write(to: file)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertNoThrow(try WallpaperPackageChecksum.verify(fileURL: file, expected: digest))
        XCTAssertThrowsError(try WallpaperPackageChecksum.verify(fileURL: file, expected: String(repeating: "0", count: 64))) { error in
            XCTAssertEqual(error as? WallpaperPackageError, .checksumMismatch)
        }
    }

    private func makeDescriptor(includeWallpaper: Bool, includeAnimation: Bool) throws -> URL {
        let root = workspace.appending(path: "Extracted", directoryHint: .isDirectory)
        let descriptor = root.appending(path: "descriptors/\(UUID().uuidString)", directoryHint: .isDirectory)
        let contents = descriptor.appending(path: "versions/1/contents", directoryHint: .isDirectory)
        let wallpaper = contents.appending(path: "123.Test.wallpaper", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: wallpaper, withIntermediateDirectories: true)
        try Data("PRPosterRoleLockScreen".utf8).write(
            to: descriptor.appending(path: "com.apple.posterkit.role.identifier")
        )
        try Data("123".utf8).write(
            to: descriptor.appending(path: "com.apple.posterkit.provider.descriptor.identifier")
        )

        if includeAnimation {
            try FileManager.default.createDirectory(
                at: wallpaper.appending(path: "123.Background.ca", directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
        if includeWallpaper {
            let plist: [String: Any] = [
                "assets": [
                    "lockAndHome": [
                        "default": ["backgroundAnimationFileName": "123.Background.ca"]
                    ]
                ]
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try data.write(to: wallpaper.appending(path: "Wallpaper.plist"))
        }
        return root
    }
}
