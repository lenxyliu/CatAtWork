import AppKit
import CatAtWorkCore
import Foundation
import ImageIO

enum LegacyCodexImportError: LocalizedError {
    case invalidMetadata
    case unsupportedVersion
    case invalidAtlas
    case cannotEncodeFrame

    var errorDescription: String? {
        switch self {
        case .invalidMetadata: "无法读取 Codex 宠物的 pet.json。"
        case .unsupportedVersion: "只支持 Codex spriteVersionNumber 2 宠物。"
        case .invalidAtlas: "Codex v2 精灵图必须是可整除的 8×11 图集。"
        case .cannotEncodeFrame: "无法转换旧宠物帧。"
        }
    }
}

private struct LegacyCodexMetadata: Decodable {
    var id: String
    var displayName: String
    var description: String
    var spriteVersionNumber: Int
    var spritesheetPath: String
}

/// Converts the established Codex 8×11 v2 atlas into a low-frame compatibility `.catpet`.
/// It intentionally preserves the original eight frames and never fabricates 24-frame motion.
struct LegacyCodexV2Importer {
    func convert(directory: URL, destination: URL) throws -> ImportedPet {
        let metadataURL = directory.appendingPathComponent("pet.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(LegacyCodexMetadata.self, from: data),
              PetManifestValidator.isSafeResourcePath(metadata.spritesheetPath) else {
            throw LegacyCodexImportError.invalidMetadata
        }
        guard metadata.spriteVersionNumber == 2 else { throw LegacyCodexImportError.unsupportedVersion }
        let atlasURL = directory.appendingPathComponent(metadata.spritesheetPath)
        guard let source = CGImageSourceCreateWithURL(atlasURL as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
              atlas.width % 8 == 0, atlas.height % 11 == 0 else {
            throw LegacyCodexImportError.invalidAtlas
        }
        let cellWidth = atlas.width / 8
        let cellHeight = atlas.height / 11
        guard cellWidth > 0, cellHeight > 0 else { throw LegacyCodexImportError.invalidAtlas }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let rowIDs = ["idle", "runRight", "runLeft", "wave", "jump", "failed", "waiting", "running", "curious"]
        var animations: [PetAnimation] = []
        for (row, id) in rowIDs.enumerated() {
            var frames: [PetFrame] = []
            for column in 0..<8 {
                let path = "frames/\(id)/\(String(format: "%03d", column)).png"
                try writeCell(atlas: atlas, column: column, row: row, cellWidth: cellWidth,
                              cellHeight: cellHeight, to: destination.appendingPathComponent(path))
                frames.append(frame(path: path, width: cellWidth, height: cellHeight, fps: 8))
            }
            animations.append(PetAnimation(id: id, loopMode: .loop, frames: frames))
        }

        var directions: [LookDirection] = []
        for index in 0..<16 {
            let row = 9 + index / 8
            let column = index % 8
            let path = "frames/lookDirections/\(String(format: "%03d", index)).png"
            try writeCell(atlas: atlas, column: column, row: row, cellWidth: cellWidth,
                          cellHeight: cellHeight, to: destination.appendingPathComponent(path))
            directions.append(LookDirection(degrees: Double(index) * 22.5,
                                            frame: frame(path: path, width: cellWidth, height: cellHeight, fps: 8)))
        }
        let manifest = PetManifest(
            id: metadata.id,
            displayName: metadata.displayName,
            author: "Codex v2 compatibility import",
            description: metadata.description,
            pixelsPerBodyUnit: Double(cellHeight),
            animations: animations,
            lookDirections: directions
        )
        try PetManifestValidator().validate(manifest, requireHighFrame: false)
        let encoded = try JSONEncoder.pretty.encode(manifest)
        try encoded.write(to: destination.appendingPathComponent("manifest.json"), options: .atomic)
        return try PetPackageImporter().inspectDirectory(at: destination)
    }

    private func frame(path: String, width: Int, height: Int, fps: Double) -> PetFrame {
        PetFrame(image: path,
                 sourceSize: PixelSize(width: width, height: height),
                 trimRect: PixelRect(x: 0, y: 0, width: width, height: height),
                 pivot: NormalizedPoint(x: 0.5, y: 0.95), duration: 1 / fps, bodyScale: 1)
    }

    private func writeCell(atlas: CGImage, column: Int, row: Int, cellWidth: Int,
                           cellHeight: Int, to url: URL) throws {
        // Core Graphics is bottom-origin while atlas rows are authored top-to-bottom.
        let rect = CGRect(x: column * cellWidth,
                          y: atlas.height - (row + 1) * cellHeight,
                          width: cellWidth, height: cellHeight)
        guard let cell = atlas.cropping(to: rect) else { throw LegacyCodexImportError.invalidAtlas }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: cell)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw LegacyCodexImportError.cannotEncodeFrame
        }
        try png.write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
