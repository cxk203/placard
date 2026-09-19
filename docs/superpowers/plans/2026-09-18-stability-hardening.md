# Placard Stability Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `.tendies` import, catalog loading, installation failure behavior, and preview memory usage predictable and testable without changing accepted extensions.

**Architecture:** Extract package validation and provider-source parsing into focused Foundation types. Keep installer orchestration in `WallpaperInstaller`, with explicit transaction cleanup supplied by `BadQuery`. Keep existing catalog UI intact while exposing source health through a small observable state.

**Tech Stack:** Swift 5, SwiftUI, Foundation, ZIPFoundation, CryptoKit, XCTest, GitHub Actions/Xcode.

## Global Constraints

- Accept only `.tendies` for local and remote installation.
- Preserve current iOS 26.0–26.6.2 and approved iOS 27 beta compatibility logic.
- Do not push, tag, release, or modify `main` until the user has tested an IPA.
- Every validation failure must leave PosterBoard unchanged for that install request.

---

### Task 1: Package validation model

**Files:**
- Create: `placard/WallpaperPackageValidator.swift`
- Create: `placardTests/WallpaperPackageValidatorTests.swift`
- Modify: `placard/WallpaperInstaller.swift`

**Interfaces:**
- Produces `WallpaperPackageValidator.validate(extractedRoot:) throws -> [String: [URL]]`.
- Produces `WallpaperPackageError` with readable failure messages.
- Consumes extracted directory tree from `WallpaperInstaller.extract`.

- [ ] Write XCTest cases for a valid descriptor, a descriptor lacking `Wallpaper.plist`, a missing `.ca` directory referenced by `Wallpaper.plist`, and an empty `descriptors` directory.
- [ ] Run tests and verify each invalid fixture fails before the validator exists.
- [ ] Implement recursive descriptor discovery and structural checks.
- [ ] Replace `findDescriptorGroups` call sites with the validator.
- [ ] Run the test target and commit the focused change.

### Task 2: Transactional descriptor write

**Files:**
- Modify: `placard/Exploit/BadQuery.swift`
- Modify: `placard/WallpaperInstaller.swift`
- Create: `placardTests/InstallTransactionTests.swift`

**Interfaces:**
- Produces `BadQuery.removeDescriptors(at:) throws`.
- `writeDescriptors` removes targets already copied if a later copy fails.
- Installer removes accumulated provider paths if a later provider fails.

- [ ] Write a test double that records copied paths and simulates a failure after one successful target.
- [ ] Run test and verify it fails before cleanup behavior exists.
- [ ] Implement compensating cleanup in both levels of the write flow.
- [ ] Run all transaction tests and commit the focused change.

### Task 3: Optional SHA-256 and source health

**Files:**
- Create: `placard/CatalogSourceHealth.swift`
- Modify: `placard/WallpaperCatalog.swift`
- Modify: `placard/WallpaperInstaller.swift`
- Create: `placardTests/WallpaperCatalogTests.swift`

**Interfaces:**
- Adds `sha256: String?` to `Wallpaper`.
- Adds a `CatalogSourceHealth` state per remote source.
- Uses CryptoKit SHA256 only when a supplied hash is exactly 64 hexadecimal characters.

- [ ] Write tests for valid hash acceptance, invalid hash rejection, and no-hash compatibility.
- [ ] Write fixture test for malformed LSNguyen JSON and cached successful JSON fallback.
- [ ] Confirm tests fail before source-health and hash behavior exists.
- [ ] Implement source-level results and stale cache fallback.
- [ ] Implement temporary-file SHA-256 verification after download and before extraction.
- [ ] Run catalog tests and commit the focused change.

### Task 4: Preview memory budget

**Files:**
- Modify: `placard/WallpaperPreviewViews.swift`
- Create: `placardTests/AnimatedImageLoaderTests.swift`

**Interfaces:**
- Caps decoded detail animation frames and image-cache total cost.
- Keeps thumbnail playback as one frame.

- [ ] Write tests for frame sampling and pixel-cost calculation.
- [ ] Verify tests fail before frame cap and cache-cost behavior exists.
- [ ] Implement bounded frame selection and cost-aware caching.
- [ ] Run preview tests and commit the focused change.

### Task 5: CI test target and local verification

**Files:**
- Modify: `placard.xcodeproj/project.pbxproj`
- Modify: `.github/workflows/ios2662-test.yml`
- Modify: `README.md`

- [ ] Add an XCTest target for pure package/catalog logic.
- [ ] Add `xcodebuild test` before archive in the test workflow.
- [ ] Document that v1.6.9 accepts `.tendies` packages only and surfaces per-source catalog errors.
- [ ] Run static checks on Windows and use the existing macOS GitHub workflow only after user authorizes a temporary remote branch.
