import Foundation
import XCTest
@testable import CatAtWorkCore

final class RuntimeStateTests: XCTestCase {
    private func frame(duration: Double = 0.01) -> PetFrame {
        PetFrame(
            image: "frames/idle/000.png",
            sourceSize: .init(width: 32, height: 32),
            trimRect: .init(x: 0, y: 0, width: 32, height: 32),
            pivot: .init(x: 0.5, y: 1),
            duration: duration
        )
    }

    private func manifest() -> PetManifest {
        PetManifest(
            id: "runtime-test",
            displayName: "Runtime test",
            author: "CatAtWork",
            description: "Reducer fixture",
            pixelsPerBodyUnit: 220,
            animations: [
                PetAnimation(id: "idle", loopMode: .loop, frames: [frame()]),
                PetAnimation(id: "wave", loopMode: .once, frames: [frame()]),
            ],
            lookDirections: []
        )
    }

    func testReplacementOwnsContractAndResetsAllCoreValues() {
        let contract = PetPackageContract(manifest: manifest())
        var state = PetRuntimeState(
            replacing: 41,
            contract: contract,
            position: .init(x: 12, y: 34)
        )
        _ = state.reduce(.clicked)
        state.setVelocity(.init(x: 90, y: -20))

        let replacement = PetRuntimeState(
            replacing: state.generation,
            contract: contract,
            position: .init(x: 50, y: 60)
        )

        XCTAssertEqual(replacement.generation, 43)
        XCTAssertEqual(replacement.contract.pixelsPerBodyUnit, 220)
        XCTAssertEqual(replacement.behavior.active.animation, "idle")
        XCTAssertEqual(replacement.behavior.queuedActionCount, 0)
        XCTAssertEqual(replacement.player.frameIndex, 0)
        XCTAssertEqual(replacement.physics.position, .init(x: 50, y: 60))
        XCTAssertEqual(replacement.physics.velocity, .init())
    }

    func testReducerRoutesEventAndKeepsDecisionObservable() {
        let contract = PetPackageContract(manifest: manifest())
        var state = PetRuntimeState(replacing: 0, contract: contract, position: .init())

        let active = state.reduce(.previewAnimation("wave"), now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(active.animation, "wave")
        XCTAssertEqual(state.behavior.lastDecision, .forced)
    }

    func testAnimationSynchronizationReturnsFinishedAnimationForReducer() {
        let value = manifest()
        let contract = PetPackageContract(manifest: value)
        var state = PetRuntimeState(replacing: 0, contract: contract, position: .init())
        _ = state.reduce(.previewAnimation("wave"), now: Date(timeIntervalSince1970: 100))

        let finished = state.synchronizeAnimation(with: value, deltaTime: 0.1)

        XCTAssertEqual(finished, "wave")
        _ = state.reduce(.animationFinished("wave"), now: Date(timeIntervalSince1970: 101))
        XCTAssertEqual(state.behavior.active.animation, "idle")
    }

    func testPhysicsStepIsSessionOwnedAndReportsLanding() {
        let contract = PetPackageContract(manifest: manifest())
        var state = PetRuntimeState(
            replacing: 0,
            contract: contract,
            position: .init(x: 50, y: 20)
        )
        state.setVelocity(.init(x: 0, y: -500))

        var landed = false
        for _ in 0..<20 {
            landed = state.stepPhysics(deltaTime: 0.05, floorY: 0, horizontalBounds: 0...100)
            if landed { break }
        }

        XCTAssertTrue(landed)
        XCTAssertEqual(state.physics.position.y, 0, accuracy: 0.0001)
        XCTAssertEqual(state.physics.velocity.y, 0, accuracy: 0.0001)
    }
}
