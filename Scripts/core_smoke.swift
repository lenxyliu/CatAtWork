import Foundation

@main
enum CoreSmokeTests {
    static func main() throws {
        var behavior = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 100)
        _ = behavior.handle(.petting, now: now)
        _ = behavior.handle(.workspaceCategory(.work), now: now)
        precondition(behavior.active.animation == "petting")

        var physics = PetPhysics(position: .init(x: 50, y: 10),
                                 velocity: .init(x: 100_000, y: -500))
        _ = physics.step(deltaTime: 1, floorY: 0, horizontalBounds: 0...100)
        precondition(abs(physics.velocity.x) <= physics.maxSpeed)
        precondition(physics.position.x <= 100)

        let frames = (0..<24).map { index in
            PetFrame(image: "frames/idle/\(index).png",
                     sourceSize: .init(width: 320, height: 360),
                     trimRect: .init(x: 10, y: 10, width: 280, height: 330),
                     pivot: .init(x: 0.5, y: 0.95), duration: 1 / 24)
        }
        let manifest = PetManifest(id: "cat-at-work", displayName: "猫上班了", author: "猫上班了",
                                   description: "smoke test", pixelsPerBodyUnit: 220,
                                   animations: [.init(id: "idle", loopMode: .loop, frames: frames)],
                                   lookDirections: [])
        try PetManifestValidator().validate(manifest, requireHighFrame: true)
        precondition(!PetManifestValidator.isSafeResourcePath("../secret.png"))
        precondition(WorkspaceClassifier().classify(bundleIdentifier: "us.zoom.xos",
                                                     windowTitle: "Meeting") == .meeting)
        if CommandLine.arguments.count > 1 {
            let imported = try PetPackageImporter().inspectDirectory(
                at: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            )
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
        }
        print("Core smoke tests passed")
    }
}
