import Foundation
import CatAtWorkCore

enum PetStoreError: LocalizedError {
    case unsafeArchiveEntry(String)
    case archiveListingFailed
    case archiveExtractionFailed
    case manifestNotAtArchiveRoot
    case compressedArchiveTooLarge
    case archiveTooLarge
    case tooManyArchiveEntries
    case archiveTooDeep
    case archiveLinkNotAllowed
    case archiveTimedOut
    case requiresNewerApp(String)
    case reservedBuiltInIdentifier

    var errorDescription: String? {
        switch self {
        case .unsafeArchiveEntry(let path): "宠物包包含不安全路径：\(path)"
        case .archiveListingFailed: "无法读取这个 .catpet 压缩包。"
        case .archiveExtractionFailed: "无法解压这个 .catpet 压缩包。"
        case .manifestNotAtArchiveRoot: "压缩包根目录必须直接包含 manifest.json。"
        case .compressedArchiveTooLarge: "宠物包压缩文件超过 256 MB 限制。"
        case .archiveTooLarge: "宠物包解压后超过 512 MB 限制。"
        case .tooManyArchiveEntries: "宠物包包含过多文件。"
        case .archiveTooDeep: "宠物包目录嵌套超过 32 层限制。"
        case .archiveLinkNotAllowed: "宠物包压缩文件不能包含符号链接。"
        case .archiveTimedOut: "宠物包处理超时。"
        case .requiresNewerApp(let version): "这个宠物需要猫上班了 \(version) 或更高版本。"
        case .reservedBuiltInIdentifier: "“cat-at-work”是应用内置小猫的保留 ID，不能被导入包覆盖。"
        }
    }
}

/// Owns installed packages. Archives are expanded into a private temporary directory, validated,
/// and only then copied into Application Support. No code from a package is ever executed.
struct PetStore: Sendable {
    private let supportRootOverride: URL?
    private let reservedIdentifiers: Set<String>

    init(
        supportRootOverride: URL? = nil,
        reservedIdentifiers: Set<String> = ["cat-at-work"]
    ) {
        self.supportRootOverride = supportRootOverride
        self.reservedIdentifiers = reservedIdentifiers
    }

    nonisolated func install(from source: URL) async throws -> ImportedPet {
        try await BackgroundIO.run {
            try await installOffMain(from: source)
        }
    }

    private nonisolated func installOffMain(from source: URL) async throws -> ImportedPet {
        let fileManager = FileManager.default
        try Task.checkCancellation()
        let inspected: ImportedPet
        var temporaryRoot: URL?
        defer {
            if let temporaryRoot { try? fileManager.removeItem(at: temporaryRoot) }
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue {
            try Task.checkCancellation()
            if fileManager.fileExists(atPath: source.appendingPathComponent("manifest.json").path) {
                inspected = try PetPackageImporter().inspectDirectory(at: source)
            } else if fileManager.fileExists(atPath: source.appendingPathComponent("pet.json").path) {
                let root = fileManager.temporaryDirectory
                    .appendingPathComponent("CatAtWork-codex-v2-\(UUID().uuidString)", isDirectory: true)
                temporaryRoot = root
                inspected = try LegacyCodexV2Importer().convert(directory: source, destination: root)
            } else {
                throw PetPackageError.manifestMissing
            }
        } else {
            let root = fileManager.temporaryDirectory
                .appendingPathComponent("CatAtWork-import-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
            temporaryRoot = root
            try await validateArchiveListing(source)
            try Task.checkCancellation()
            try await extractArchive(source, to: root)
            try Task.checkCancellation()
            guard fileManager.fileExists(atPath: root.appendingPathComponent("manifest.json").path) else {
                throw PetStoreError.manifestNotAtArchiveRoot
            }
            inspected = try PetPackageImporter().inspectDirectory(at: root)
        }

        let currentVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        if let required = AppVersion(inspected.manifest.minimumAppVersion),
           let current = AppVersion(currentVersionString), required > current {
            throw PetStoreError.requiresNewerApp(inspected.manifest.minimumAppVersion)
        }
        guard !reservedIdentifiers.contains(inspected.manifest.id) else {
            throw PetStoreError.reservedBuiltInIdentifier
        }

        try Task.checkCancellation()
        let support = if let supportRootOverride {
            supportRootOverride
        } else {
            try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)
                .appendingPathComponent("猫上班了/Pets", isDirectory: true)
        }
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        let destination = support.appendingPathComponent("\(inspected.manifest.id).catpet", isDirectory: true)
        let staging = support.appendingPathComponent(".\(inspected.manifest.id)-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: inspected.rootURL, to: staging)
        try Task.checkCancellation()
        _ = try PetPackageImporter().inspectDirectory(at: staging)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
        return try PetPackageImporter().inspectDirectory(at: destination)
    }

    private nonisolated func validateArchiveListing(_ archive: URL) async throws {
        try await validateArchiveTotals(archive)
        let result: ProcessRunResult
        do {
            result = try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                arguments: ["-Z1", archive.path],
                timeout: .seconds(30),
                maximumCapturedOutputBytes: 4 * 1_024 * 1_024
            )
        } catch ProcessRunError.timedOut {
            throw PetStoreError.archiveTimedOut
        } catch ProcessRunError.cancelled {
            throw CancellationError()
        } catch {
            throw PetStoreError.archiveListingFailed
        }
        guard result.terminationStatus == 0, !result.outputWasTruncated,
              let listing = String(data: result.output, encoding: .utf8) else {
            throw PetStoreError.archiveListingFailed
        }
        for entry in listing.split(whereSeparator: \Character.isNewline).map(String.init) {
            guard PetManifestValidator.isSafeResourcePath(entry), !entry.hasPrefix("__MACOSX/") else {
                throw PetStoreError.unsafeArchiveEntry(entry)
            }
            guard entry.split(separator: "/", omittingEmptySubsequences: true).count <= 32 else {
                throw PetStoreError.archiveTooDeep
            }
        }
        try await validateArchiveAttributes(archive)
    }

    private nonisolated func validateArchiveTotals(_ archive: URL) async throws {
        let values = try archive.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              Int64(values.fileSize ?? 0) <= 256 * 1_024 * 1_024 else {
            throw PetStoreError.compressedArchiveTooLarge
        }
        let result: ProcessRunResult
        do {
            result = try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/unzip"),
                arguments: ["-Z", "-t", archive.path],
                timeout: .seconds(30),
                maximumCapturedOutputBytes: 64 * 1_024
            )
        } catch ProcessRunError.timedOut {
            throw PetStoreError.archiveTimedOut
        } catch ProcessRunError.cancelled {
            throw CancellationError()
        } catch {
            throw PetStoreError.archiveListingFailed
        }
        guard result.terminationStatus == 0, !result.outputWasTruncated,
              let summary = String(data: result.output, encoding: .utf8) else {
            throw PetStoreError.archiveListingFailed
        }
        let fields = summary.split(separator: " ")
        guard fields.count >= 4,
              let entries = Int(fields[0]),
              let uncompressedBytes = Int64(fields[2]) else {
            throw PetStoreError.archiveListingFailed
        }
        guard entries <= 5_000 else { throw PetStoreError.tooManyArchiveEntries }
        guard uncompressedBytes <= 512 * 1_024 * 1_024 else { throw PetStoreError.archiveTooLarge }
    }

    private nonisolated func extractArchive(_ archive: URL, to destination: URL) async throws {
        do {
            let result = try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
                arguments: ["-x", "-k", "--noqtn", archive.path, destination.path],
                timeout: .seconds(120),
                maximumCapturedOutputBytes: 256 * 1_024
            )
            guard result.terminationStatus == 0, !result.outputWasTruncated else {
                throw PetStoreError.archiveExtractionFailed
            }
        } catch ProcessRunError.timedOut {
            throw PetStoreError.archiveTimedOut
        } catch ProcessRunError.cancelled {
            throw CancellationError()
        } catch let error as PetStoreError {
            throw error
        } catch {
            throw PetStoreError.archiveExtractionFailed
        }
    }

    private nonisolated func validateArchiveAttributes(_ archive: URL) async throws {
        let result: ProcessRunResult
        do {
            result = try await AsyncProcessRunner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/zipinfo"),
                arguments: ["-l", archive.path],
                timeout: .seconds(30),
                maximumCapturedOutputBytes: 4 * 1_024 * 1_024
            )
        } catch ProcessRunError.timedOut {
            throw PetStoreError.archiveTimedOut
        } catch ProcessRunError.cancelled {
            throw CancellationError()
        } catch {
            throw PetStoreError.archiveListingFailed
        }
        guard result.terminationStatus == 0, !result.outputWasTruncated,
              let attributes = String(data: result.output, encoding: .utf8) else {
            throw PetStoreError.archiveListingFailed
        }
        for line in attributes.split(whereSeparator: \Character.isNewline) {
            // `zipinfo -l` entry rows begin with Unix file-type/permission
            // characters. Symlinks are rejected before extraction so a later
            // archive entry cannot traverse one into the host filesystem.
            if line.first == "l" {
                throw PetStoreError.archiveLinkNotAllowed
            }
        }
    }
}
