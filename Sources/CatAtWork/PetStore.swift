import Foundation
import CatAtWorkCore

enum PetStoreError: LocalizedError {
    case unsafeArchiveEntry(String)
    case archiveListingFailed
    case archiveExtractionFailed
    case manifestNotAtArchiveRoot
    case archiveTooLarge
    case tooManyArchiveEntries
    case requiresNewerApp(String)
    case reservedBuiltInIdentifier

    var errorDescription: String? {
        switch self {
        case .unsafeArchiveEntry(let path): "宠物包包含不安全路径：\(path)"
        case .archiveListingFailed: "无法读取这个 .catpet 压缩包。"
        case .archiveExtractionFailed: "无法解压这个 .catpet 压缩包。"
        case .manifestNotAtArchiveRoot: "压缩包根目录必须直接包含 manifest.json。"
        case .archiveTooLarge: "宠物包解压后超过 512 MB 限制。"
        case .tooManyArchiveEntries: "宠物包包含过多文件。"
        case .requiresNewerApp(let version): "这个宠物需要猫上班了 \(version) 或更高版本。"
        case .reservedBuiltInIdentifier: "“cat-at-work”是应用内置小猫的保留 ID，不能被导入包覆盖。"
        }
    }
}

/// Owns installed packages. Archives are expanded into a private temporary directory, validated,
/// and only then copied into Application Support. No code from a package is ever executed.
struct PetStore {
    private let fileManager = FileManager.default
    private let supportRootOverride: URL?
    private let reservedIdentifiers: Set<String>

    init(
        supportRootOverride: URL? = nil,
        reservedIdentifiers: Set<String> = ["cat-at-work"]
    ) {
        self.supportRootOverride = supportRootOverride
        self.reservedIdentifiers = reservedIdentifiers
    }

    func install(from source: URL) throws -> ImportedPet {
        let inspected: ImportedPet
        var temporaryRoot: URL?
        defer {
            if let temporaryRoot { try? fileManager.removeItem(at: temporaryRoot) }
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue {
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
            try validateArchiveListing(source)
            try extractArchive(source, to: root)
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
        try fileManager.copyItem(at: inspected.rootURL, to: staging)
        _ = try PetPackageImporter().inspectDirectory(at: staging)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
        return try PetPackageImporter().inspectDirectory(at: destination)
    }

    private func validateArchiveListing(_ archive: URL) throws {
        try validateArchiveTotals(archive)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", archive.path]
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PetStoreError.archiveListingFailed }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard data.count <= 4 * 1_024 * 1_024,
              let listing = String(data: data, encoding: .utf8) else {
            throw PetStoreError.archiveListingFailed
        }
        for entry in listing.split(whereSeparator: \Character.isNewline).map(String.init) {
            guard PetManifestValidator.isSafeResourcePath(entry), !entry.hasPrefix("__MACOSX/") else {
                throw PetStoreError.unsafeArchiveEntry(entry)
            }
        }
    }

    private func validateArchiveTotals(_ archive: URL) throws {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z", "-t", archive.path]
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let summary = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
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

    private func extractArchive(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", "--noqtn", archive.path, destination.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PetStoreError.archiveExtractionFailed }
    }
}
