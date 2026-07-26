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
    case canonicalContentInvalid(String)
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

    /// Application/UI callers use this entry point so directory traversal and
    /// image decoding never inherit a main-actor executor.
    public func inspectDirectoryAsync(at root: URL) async throws -> ImportedPet {
        try await BackgroundIO.run {
            try inspectDirectory(at: root)
        }
    }

    public func inspectDirectory(at root: URL) throws -> ImportedPet {
        try Task.checkCancellation()
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
            try Task.checkCancellation()
            let values = try file.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values.fileSize ?? 0)
            guard total <= maximumPackageBytes else { throw PetPackageError.packageTooLarge }
        }
        let framePaths = manifest.animations.flatMap(\.frames).map(\.image) + manifest.lookDirections.map(\.frame.image)
        var imageSizes: [String: PixelSize] = [:]
        for relativePath in Set(framePaths) {
            try Task.checkCancellation()
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
            try Task.checkCancellation()
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
        if manifest.formatVersion == 2 {
            try validateCanonicalContent(
                manifest: manifest,
                root: root,
                imageSizes: imageSizes
            )
        }

        let highFrame = manifest.animations.allSatisfy { $0.frames.count >= 24 }
        return ImportedPet(rootURL: root, manifest: manifest, isHighFrame: highFrame)
    }

    private func validateCanonicalContent(
        manifest: PetManifest,
        root: URL,
        imageSizes: [String: PixelSize]
    ) throws {
        guard let canvas = manifest.authoredCanvas,
              let policy = manifest.componentPolicy else {
            throw PetPackageError.canonicalContentInvalid("missing canonical policy")
        }
        let animationFrames = manifest.animations.flatMap { animation in
            animation.frames.enumerated().map {
                (animation.id, $0.offset, $0.element)
            }
        }
        let lookFrames = manifest.lookDirections.enumerated().map {
            ("lookDirections", $0.offset, $0.element.frame)
        }
        let scopedFrames = animationFrames + lookFrames
        let grouped = Dictionary(grouping: scopedFrames, by: { $0.2.image })

        for (relativePath, frames) in grouped {
            guard imageSizes[relativePath] != nil else {
                throw PetPackageError.resourceMissing(relativePath)
            }
            let url = root.appendingPathComponent(relativePath)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw PetPackageError.invalidImage(relativePath)
            }
            for (animation, frameIndex, frame) in frames {
                let crop: CGImage
                if let texture = frame.textureRect {
                    guard let extracted = atlas.cropping(
                        to: CGRect(
                            x: texture.x,
                            y: texture.y,
                            width: texture.width,
                            height: texture.height
                        )
                    ) else {
                        throw PetPackageError.canonicalContentInvalid(
                            "\(animation) frame \(frameIndex): invalid atlas crop"
                        )
                    }
                    crop = extracted
                } else {
                    crop = atlas
                }
                guard crop.width == canvas.width, crop.height == canvas.height,
                      let alpha = Self.alphaBytes(from: crop) else {
                    throw PetPackageError.canonicalContentInvalid(
                        "\(animation) frame \(frameIndex): invalid canonical RGBA crop"
                    )
                }
                guard let bounds = Self.alphaBounds(
                    alpha,
                    width: crop.width,
                    height: crop.height
                ),
                      bounds.minX >= canvas.safeMargin,
                      bounds.minY >= canvas.safeMargin,
                      crop.width - bounds.maxX - 1 >= canvas.safeMargin,
                      crop.height - bounds.maxY - 1 >= canvas.safeMargin else {
                    throw PetPackageError.canonicalContentInvalid(
                        "\(animation) frame \(frameIndex): safe margin"
                    )
                }
                let areas = Self.componentAreas(
                    alpha,
                    width: crop.width,
                    height: crop.height,
                    threshold: policy.alphaThreshold,
                    minimumArea: policy.minimumArea
                )
                guard !areas.isEmpty else {
                    throw PetPackageError.canonicalContentInvalid(
                        "\(animation) frame \(frameIndex): empty material"
                    )
                }
                let secondary = Array(areas.dropFirst())
                let matching = policy.exceptions.filter {
                    $0.animation == animation &&
                        $0.frames.contains(frameIndex) &&
                        $0.reviewId == frame.componentExceptionReviewId
                }
                if secondary.isEmpty {
                    guard frame.componentExceptionReviewId == nil else {
                        throw PetPackageError.canonicalContentInvalid(
                            "\(animation) frame \(frameIndex): unused component exception"
                        )
                    }
                } else {
                    guard matching.count == 1,
                          secondary.count <= matching[0].maximumSecondaryComponents,
                          (secondary.max() ?? 0) <= matching[0].maximumSecondaryArea else {
                        throw PetPackageError.canonicalContentInvalid(
                            "\(animation) frame \(frameIndex): disconnected components"
                        )
                    }
                }
            }
        }
    }

    private static func alphaBytes(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue |
            CGImageAlphaInfo.premultipliedLast.rawValue
        let created = rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard created else { return nil }
        return stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }

    private static func alphaBounds(
        _ alpha: [UInt8],
        width: Int,
        height: Int
    ) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        return maxX >= 0 ? (minX, minY, maxX, maxY) : nil
    }

    private static func componentAreas(
        _ alpha: [UInt8],
        width: Int,
        height: Int,
        threshold: Int,
        minimumArea: Int
    ) -> [Int] {
        var seen = [Bool](repeating: false, count: alpha.count)
        var areas: [Int] = []
        for start in alpha.indices where !seen[start] && alpha[start] >= threshold {
            seen[start] = true
            var stack = [start]
            var area = 0
            while let current = stack.popLast() {
                area += 1
                let x = current % width
                let y = current / width
                for nextY in max(0, y - 1)...min(height - 1, y + 1) {
                    for nextX in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = nextY * width + nextX
                        if !seen[next], alpha[next] >= threshold {
                            seen[next] = true
                            stack.append(next)
                        }
                    }
                }
            }
            if area >= minimumArea { areas.append(area) }
        }
        return areas.sorted(by: >)
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
            try Task.checkCancellation()
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
