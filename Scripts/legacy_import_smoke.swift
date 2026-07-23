import Foundation

@main
enum LegacyImportSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw NSError(domain: "LegacyImportSmoke", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "usage: smoke <legacy-directory> <output-directory>"])
        }
        let imported = try LegacyCodexV2Importer().convert(
            directory: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true),
            destination: URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        )
        precondition(imported.manifest.animations.count == 9)
        precondition(imported.manifest.animations.allSatisfy { $0.frames.count == 8 })
        precondition(imported.manifest.lookDirections.count == 16)
        precondition(!imported.isHighFrame)
        print("Legacy Codex v2 import smoke test passed")
    }
}
