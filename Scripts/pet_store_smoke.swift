import Foundation

@main
enum PetStoreSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
            throw NSError(domain: "PetStoreSmoke", code: 2)
        }
        let support = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try? FileManager.default.removeItem(at: support)
        let expectReservedRejection = CommandLine.arguments.last == "--expect-reserved-reject"
        let store = PetStore(
            supportRootOverride: support,
            reservedIdentifiers: expectReservedRejection ? ["cat-at-work"] : []
        )
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        if expectReservedRejection {
            do {
                _ = try store.install(from: source)
                preconditionFailure("built-in pet ID was accepted as an imported package")
            } catch PetStoreError.reservedBuiltInIdentifier {
                print("Built-in pet ID rejection smoke test passed")
                return
            }
        }
        if CommandLine.arguments.last == "--expect-reject" {
            do {
                _ = try store.install(from: source)
                preconditionFailure("unsafe archive was accepted")
            } catch PetStoreError.unsafeArchiveEntry {
                print("Unsafe archive rejection smoke test passed")
                return
            }
        }
        let imported = try store.install(from: source)
        precondition(imported.isHighFrame)
        let expectedActions: Set<String> = [
            "idle", "idleEar", "idleTail", "sitToStand", "standToSit", "lieDown", "getUp",
            "walkLeft", "walkRight", "runLeft", "runRight",
            "groom", "wave", "petting", "earPet", "chinPet", "backPet", "bellyPet",
            "pickup", "thrown", "landing", "jump", "bellyRoll", "sleep", "wakeUp",
            "curious", "working", "waiting", "happy", "startled", "failed",
        ]
        precondition(Set(imported.manifest.animations.map(\.id)) == expectedActions)
        precondition(imported.manifest.animations.allSatisfy { $0.frames.count >= 24 })
        precondition(imported.manifest.lookDirections.count == 16)
        precondition(imported.rootURL.standardizedFileURL.path.hasPrefix(support.standardizedFileURL.path + "/"))
        print("ZIP .catpet installation smoke test passed")
    }
}
