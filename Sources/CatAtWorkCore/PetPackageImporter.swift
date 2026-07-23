import Foundation
import ImageIO

public enum PetPackageError: Error, Equatable {
    case packageTooLarge
    case manifestTooLarge
    case manifestMissing
    case resourceMissing(String)
    case resourceTooLarge(String)
    case unsupportedPackageType
    case symbolicLinkNotAllowed(String)
    case invalidImage(String)
    case imageTooLarge(String)
    case transparencyRequired(String)
    case tooManyResources
    case unsupportedResource(String)
    case executableResourceNotAllowed(String)
}

public struct ImportedPet: Sendable {
    public let rootURL: URL
    public let manifest: PetManifest
    public let isHighFrame: Bool
}

public struct PetPackageImporter: Sendable {
    public var maximumPackageBytes: Int64 = 512 * 1_024 * 1_024
    public var maximumResourceBytes: Int64 = 32 * 1_024 * 1_024
    public var maximumManifestBytes: Int64 = 4 * 1_024 * 1_024

    public init() {}

    public func inspectDirectory(at root: URL) throws -> ImportedPet {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PetPackageError.unsupportedPackageType
        }
        let rootValues = try root.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard rootValues.isSymbolicLink != true else { throw PetPackageError.symbolicLinkNotAllowed(root.lastPathComponent) }

        let manifestURL = root.appendingPathComponent("manifest.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { throw PetPackageError.manifestMissing }
        let packageFiles = try validatePackageFiles(root: root)
        let manifestValues = try manifestURL.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey])
        guard manifestValues.isSymbolicLink != true, manifestValues.isRegularFile == true else {
            throw PetPackageError.symbolicLinkNotAllowed("manifest.json")
        }
        guard Int64(manifestValues.fileSize ?? 0) <= maximumManifestBytes else {
            throw PetPackageError.manifestTooLarge
        }
        let manifestData = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        let manifest = try JSONDecoder().decode(PetManifest.self, from: manifestData)
        try PetManifestValidator().validate(manifest, requireHighFrame: false)

        var total: Int64 = 0
        for file in packageFiles {
            let values = try file.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values.fileSize ?? 0)
            guard total <= maximumPackageBytes else { throw PetPackageError.packageTooLarge }
        }
        let framePaths = manifest.animations.flatMap(\.frames).map(\.image) + manifest.lookDirections.map(\.frame.image)
        var imageSizes: [String: PixelSize] = [:]
        for relativePath in Set(framePaths) {
            guard PetManifestValidator.isSafeResourcePath(relativePath) else { throw PetManifestIssue.invalidFramePath(relativePath) }
            let url = root.appendingPathComponent(relativePath).standardizedFileURL
            guard url.path.hasPrefix(root.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: url.path) else {
                throw PetPackageError.resourceMissing(relativePath)
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw PetPackageError.symbolicLinkNotAllowed(relativePath)
            }
            let size = values.fileSize.map(Int64.init) ?? 0
            guard size <= maximumResourceBytes else { throw PetPackageError.resourceTooLarge(relativePath) }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw PetPackageError.invalidImage(relativePath)
            }
            guard image.width <= 8_192, image.height <= 8_192 else {
                throw PetPackageError.imageTooLarge(relativePath)
            }
            imageSizes[relativePath] = PixelSize(width: image.width, height: image.height)
            switch image.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly: break
            default: throw PetPackageError.transparencyRequired(relativePath)
            }
        }

        let allFrames = manifest.animations.flatMap(\.frames) + manifest.lookDirections.map(\.frame)
        for frame in allFrames {
            guard let imageSize = imageSizes[frame.image] else { throw PetPackageError.resourceMissing(frame.image) }
            if let texture = frame.textureRect {
                guard texture.x >= 0, texture.y >= 0,
                      texture.width == frame.sourceSize.width,
                      texture.height == frame.sourceSize.height,
                      texture.x + texture.width <= imageSize.width,
                      texture.y + texture.height <= imageSize.height else {
                    throw PetPackageError.invalidImage(frame.image)
                }
            } else if imageSize != frame.sourceSize {
                throw PetPackageError.invalidImage(frame.image)
            }
        }

        let highFrame = manifest.animations.allSatisfy { $0.frames.count >= 24 }
        return ImportedPet(rootURL: root, manifest: manifest, isHighFrame: highFrame)
    }

    private func validatePackageFiles(root: URL) throws -> [URL] {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: canonicalRoot,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { throw PetPackageError.unsupportedPackageType }

        var files: [URL] = []
        let allowedExtensions = Set(["json", "png", "webp", "jpg", "jpeg", "heic", "wav", "aiff", "aif", "caf", "m4a", "mp3"])
        for case let url as URL in enumerator {
            let relative = String(url.standardizedFileURL.path.dropFirst(canonicalRoot.path.count + 1))
            guard PetManifestValidator.isSafeResourcePath(relative) else {
                throw PetManifestIssue.invalidFramePath(relative)
            }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true else { throw PetPackageError.symbolicLinkNotAllowed(relative) }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw PetPackageError.unsupportedResource(relative) }
            let fileSize = Int64(values.fileSize ?? 0)
            if relative == "manifest.json" {
                guard fileSize <= maximumManifestBytes else { throw PetPackageError.manifestTooLarge }
            } else {
                guard fileSize <= maximumResourceBytes else { throw PetPackageError.resourceTooLarge(relative) }
            }
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
                throw PetPackageError.unsupportedResource(relative)
            }
            if relative != "manifest.json" {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let permissions = attributes[.posixPermissions] as? NSNumber,
                   permissions.intValue & 0o111 != 0 {
                    throw PetPackageError.executableResourceNotAllowed(relative)
                }
            }
            files.append(url)
            guard files.count <= 5_000 else { throw PetPackageError.tooManyResources }
        }
        return files
    }
}
