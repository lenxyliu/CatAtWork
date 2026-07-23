import Foundation
import XCTest
@testable import CatAtWorkCore

private func frame(_ index: Int = 0) -> PetFrame {
    PetFrame(image: "frames/idle/\(index).png",
             sourceSize: .init(width: 320, height: 360),
             trimRect: .init(x: 10, y: 10, width: 280, height: 330),
             pivot: .init(x: 0.5, y: 0.95), duration: 1.0 / 24.0)
}

private func manifest(frameCount: Int = 24) -> PetManifest {
    PetManifest(id: "cat-at-work", displayName: "猫上班了", author: "猫上班了",
                description: "陪你认真工作，也会偷偷舔毛的长毛猫。", pixelsPerBodyUnit: 220,
                animations: [PetAnimation(id: "idle", loopMode: .loop,
                                          frames: (0..<frameCount).map(frame))],
                lookDirections: [])
}

private func animation(
    _ id: String,
    loopMode: LoopMode = .once,
    nextAnimation: String? = nil,
    startPose: PetPose? = .seated,
    endPose: PetPose? = .seated
) -> PetAnimation {
    PetAnimation(
        id: id,
        loopMode: loopMode,
        nextAnimation: nextAnimation,
        startPose: startPose?.rawValue,
        endPose: endPose?.rawValue,
        frames: [frame()]
    )
}

final class PetManifestTests: XCTestCase {
    func testAcceptsHighFrameManifest() throws {
        try PetManifestValidator().validate(manifest(), requireHighFrame: true)
    }

    func testRejectsLowFrameManifestWhenRequired() {
        XCTAssertThrowsError(try PetManifestValidator().validate(manifest(frameCount: 8), requireHighFrame: true)) {
            XCTAssertEqual($0 as? PetManifestIssue, .insufficientFrames(animation: "idle", actual: 8))
        }
    }

    func testRejectsTraversalPaths() {
        XCTAssertFalse(PetManifestValidator.isSafeResourcePath("../secret.png"))
        XCTAssertFalse(PetManifestValidator.isSafeResourcePath("frames/../../secret.png"))
        XCTAssertTrue(PetManifestValidator.isSafeResourcePath("frames/idle/001.png"))
    }

    func testPreservesPerFrameSourceSize() throws {
        var value = manifest()
        value.animations[0].frames[1].sourceSize = .init(width: 560, height: 420)
        value.animations[0].frames[1].trimRect = .init(x: 0, y: 0, width: 550, height: 410)
        try PetManifestValidator().validate(value, requireHighFrame: true)
    }

    func testCanvasLayoutAccountsForDifferentPivotExtents() {
        var leftHeavy = frame()
        leftHeavy.sourceSize = .init(width: 100, height: 100)
        leftHeavy.trimRect = .init(x: 0, y: 0, width: 100, height: 100)
        leftHeavy.pivot = .init(x: 0.8, y: 0.9)
        var rightHeavy = leftHeavy
        rightHeavy.pivot = .init(x: 0.2, y: 0.4)

        let layout = PetCanvasLayout(frames: [leftHeavy, rightHeavy], margin: 10)

        XCTAssertEqual(layout.size, .init(width: 180, height: 170))
        XCTAssertEqual(layout.anchorFromTop, .init(x: 90, y: 100))
        for candidate in [leftHeavy, rightHeavy] {
            let origin = layout.origin(for: candidate)
            XCTAssertGreaterThanOrEqual(origin.x, 10)
            XCTAssertGreaterThanOrEqual(origin.y, 10)
            XCTAssertLessThanOrEqual(origin.x + 100, Double(layout.size.width) - 10)
            XCTAssertLessThanOrEqual(origin.y + 100, Double(layout.size.height) - 10)
        }
    }

    func testCanvasLayoutAccountsForJumpRenderOffsetWithoutChangingBodyScale() throws {
        var grounded = frame()
        grounded.sourceSize = .init(width: 100, height: 100)
        grounded.trimRect = .init(x: 0, y: 0, width: 100, height: 100)
        grounded.pivot = .init(x: 0.5, y: 1)
        var airborne = grounded
        airborne.renderOffset = .init(x: 12, y: -80)

        let layout = PetCanvasLayout(frames: [grounded, airborne], margin: 10)
        let groundedOrigin = layout.origin(for: grounded)
        let airborneOrigin = layout.origin(for: airborne)

        XCTAssertEqual(airborneOrigin.x - groundedOrigin.x, 12, accuracy: 0.001)
        XCTAssertEqual(airborneOrigin.y - groundedOrigin.y, -80, accuracy: 0.001)
        XCTAssertEqual(grounded.bodyScale, airborne.bodyScale)

        var value = manifest()
        value.animations[0].frames[0].renderOffset = .init(x: 12, y: -80)
        try PetManifestValidator().validate(value, requireHighFrame: true)
    }

    func testCanvasSafetyMarginDoesNotLiftFootAnchorOffDesktopFloor() {
        var grounded = frame()
        grounded.sourceSize = .init(width: 100, height: 100)
        grounded.trimRect = .init(x: 0, y: 0, width: 100, height: 100)
        grounded.pivot = .init(x: 0.5, y: 0.9)
        var belowAnchor = grounded
        belowAnchor.sourceSize = .init(width: 220, height: 240)
        belowAnchor.trimRect = .init(x: 0, y: 0, width: 220, height: 240)
        belowAnchor.pivot = .init(x: 0.5, y: 0.5)

        let layout = PetCanvasLayout(frames: [grounded, belowAnchor], margin: 16)
        let scale = 0.45
        let floor = 42.0
        let origin = layout.windowOriginY(placingAnchorAt: floor, scale: scale)

        XCTAssertEqual(layout.anchorWorldY(forWindowOriginY: origin, scale: scale), floor, accuracy: 0.001)
        XCTAssertLessThan(origin, floor, "Transparent safety pixels may extend below the floor without lifting the cat")
    }

    func testValidatesAndComparesMinimumAppVersion() throws {
        XCTAssertLessThan(AppVersion("1.2.9")!, AppVersion("1.3.0")!)
        XCTAssertEqual(AppVersion("1.0")!, AppVersion("1.0.0")!)
        var value = manifest()
        value.minimumAppVersion = "next"
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidMinimumAppVersion)
        }
    }

    func testRejectsOversizedMetadataAndUnknownNextAnimation() {
        var value = manifest()
        value.displayName = String(repeating: "猫", count: 81)
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidMetadata("displayName"))
        }

        value = manifest()
        value.animations[0].nextAnimation = "missing"
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidNextAnimation("missing"))
        }
    }

    func testRejectsNonFiniteScaleAndUnsupportedPose() {
        var value = manifest()
        value.pixelsPerBodyUnit = .infinity
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidFrameGeometry("pixelsPerBodyUnit"))
        }

        value = manifest()
        value.animations[0].startPose = "crouching"
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual(
                $0 as? PetManifestIssue,
                .invalidPose(animation: "idle", pose: "crouching")
            )
        }
    }

    func testExactLookupAndSemanticFallbackNeverSilentlyUseIdle() {
        var value = manifest()
        value.animations.append(animation("petting"))
        let contract = PetPackageContract(manifest: value)

        XCTAssertNil(value.animation(named: "missing"))
        XCTAssertEqual(contract.resolvedAnimationID(for: "earPet"), "petting")
        XCTAssertNil(contract.resolvedAnimationID(for: "walkRight"))

        var engine = BehaviorEngine(contract: contract)
        _ = engine.handle(.autonomousWalkRight)
        XCTAssertEqual(engine.active.animation, "idle")
        XCTAssertEqual(engine.queuedActionCount, 0)
        XCTAssertEqual(engine.lastDecision, .ignoredUnavailable)
    }

    func testPackageScaleNormalizesPixelDensityAndInteractionUsesTrimFallback() {
        var value = manifest()
        value.pixelsPerBodyUnit = 440
        let contract = PetPackageContract(manifest: value)
        XCTAssertEqual(contract.canvasScale(userScale: 0.45), 0.225, accuracy: 0.000_001)

        var candidate = frame()
        XCTAssertEqual(candidate.interactionRect, candidate.trimRect)
        candidate.collisionRect = .init(x: 20, y: 30, width: 100, height: 120)
        XCTAssertEqual(candidate.interactionRect, candidate.collisionRect)
    }

    func testManifestPoseGraphUsesOnlyAvailableAuthoredBridges() {
        var value = manifest()
        value.animations[0].startPose = PetPose.lying.rawValue
        value.animations[0].endPose = PetPose.lying.rawValue
        value.animations.append(animation("customStand", startPose: .standing, endPose: .standing))

        var contract = PetPackageContract(manifest: value)
        XCTAssertEqual(contract.initialPose, .lying)
        XCTAssertNil(contract.poseRouter.transitions(from: .lying, to: .standing))

        value.animations.append(animation("getUp", startPose: .lying, endPose: .seated))
        value.animations.append(animation("sitToStand", startPose: .seated, endPose: .standing))
        contract = PetPackageContract(manifest: value)
        XCTAssertEqual(
            contract.poseRouter.transitions(from: .lying, to: .standing),
            ["getUp", "sitToStand"]
        )

        value.animations.append(animation("legacyCustom", startPose: nil, endPose: nil))
        contract = PetPackageContract(manifest: value)
        XCTAssertEqual(contract.poseRouter.startPose(for: "legacyCustom"), .seated)
        XCTAssertEqual(contract.poseRouter.endPose(for: "legacyCustom"), .seated)
    }

    func testCustomIdlePoseRoutesOutAndBackThroughPackageBridges() {
        var value = manifest()
        value.animations[0].startPose = PetPose.lying.rawValue
        value.animations[0].endPose = PetPose.lying.rawValue
        value.animations.append(animation("getUp", startPose: .lying, endPose: .seated))
        value.animations.append(animation("lieDown", startPose: .seated, endPose: .lying))
        value.animations.append(animation("wave"))
        var engine = BehaviorEngine(contract: PetPackageContract(manifest: value))
        let now = Date(timeIntervalSince1970: 675)

        _ = engine.handle(.previewAnimation("wave"), now: now)
        XCTAssertEqual(engine.active.animation, "getUp")
        _ = engine.handle(.animationFinished("getUp"), now: now.addingTimeInterval(0.1))
        XCTAssertEqual(engine.active.animation, "wave")
        _ = engine.handle(.animationFinished("wave"), now: now.addingTimeInterval(0.2))
        XCTAssertEqual(engine.active.animation, "lieDown")
        _ = engine.handle(.animationFinished("lieDown"), now: now.addingTimeInterval(0.3))
        XCTAssertEqual(engine.active.animation, "idle")
        XCTAssertEqual(engine.pose, .lying)
    }

    func testNextAnimationRunsOnlyWhenRuntimeCompletionIsUnclaimed() {
        var value = manifest()
        value.animations.append(animation("wave", nextAnimation: "happy"))
        value.animations.append(animation("happy"))
        value.animations.append(animation("petting"))
        let contract = PetPackageContract(manifest: value)
        let now = Date(timeIntervalSince1970: 700)

        var engine = BehaviorEngine(contract: contract)
        _ = engine.handle(.previewAnimation("wave"), now: now)
        _ = engine.handle(.animationFinished("wave"), now: now.addingTimeInterval(0.1))
        XCTAssertEqual(engine.active.animation, "happy")

        engine = BehaviorEngine(contract: contract)
        _ = engine.handle(.previewAnimation("wave"), now: now)
        _ = engine.handle(.petting, now: now.addingTimeInterval(0.1))
        _ = engine.handle(.animationFinished("wave"), now: now.addingTimeInterval(0.2))
        XCTAssertEqual(engine.active.animation, "petting")
    }

    func testAnimationPlayerCanRestartSelfReferentialNextAnimation() {
        let oneShot = animation("wave")
        var player = AnimationPlayer(animationID: "wave")
        _ = player.advance(deltaTime: 0.25, animation: oneShot)
        XCTAssertTrue(player.isFinished(animation: oneShot))

        player.restart()
        XCTAssertEqual(player.frameIndex, 0)
        XCTAssertEqual(player.elapsedInFrame, 0)
        XCTAssertFalse(player.isFinished(animation: oneShot))
    }

    func testIncompletePhysicalChainIsUnavailableAndCoreSessionStartsFresh() {
        var value = manifest()
        value.animations[0].startPose = PetPose.lying.rawValue
        value.animations[0].endPose = PetPose.lying.rawValue
        value.animations.append(animation("pickup", startPose: .seated, endPose: .hanging))
        let contract = PetPackageContract(manifest: value)
        XCTAssertFalse(contract.supportsPhysicalInteraction)

        var priorEngine = BehaviorEngine()
        _ = priorEngine.handle(.clicked)
        XCTAssertNotEqual(priorEngine.active.animation, "idle")

        var engine = BehaviorEngine(contract: contract)
        _ = engine.handle(.grabbed)
        XCTAssertEqual(engine.active.animation, "idle")
        XCTAssertEqual(engine.lastDecision, .ignoredUnavailable)

        let session = PetSessionCoreState(
            replacing: 41,
            contract: contract,
            position: .init(x: 12, y: 34)
        )
        XCTAssertEqual(session.generation, 42)
        XCTAssertEqual(session.behavior.active.animation, "idle")
        XCTAssertEqual(session.behavior.pose, .lying)
        XCTAssertEqual(session.behavior.queuedActionCount, 0)
        XCTAssertEqual(session.player.animationID, "idle")
        XCTAssertEqual(session.player.frameIndex, 0)
        XCTAssertEqual(session.physics.position, .init(x: 12, y: 34))
        XCTAssertEqual(session.physics.velocity, .init())
        XCTAssertNil(session.physics.lastImpactVelocityY)
    }

    func testLookDirectionsReceiveFullFrameGeometryValidation() {
        var value = manifest()
        value.lookDirections = (0..<16).map { index in
            var lookFrame = frame()
            if index == 7 { lookFrame.pivot = .init(x: 1.5, y: 0.5) }
            return LookDirection(degrees: Double(index) * 22.5, frame: lookFrame)
        }
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidFrameGeometry("lookDirections"))
        }
    }

    func testImporterRejectsManifestBeforeReadingOversizedPayload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try JSONEncoder().encode(manifest(frameCount: 1)).write(to: root.appendingPathComponent("manifest.json"))
        var importer = PetPackageImporter()
        importer.maximumManifestBytes = 16
        XCTAssertThrowsError(try importer.inspectDirectory(at: root)) {
            XCTAssertEqual($0 as? PetPackageError, .manifestTooLarge)
        }
    }

    func testImporterRejectsUnreferencedExecutableAndCountsAllFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try JSONEncoder().encode(manifest(frameCount: 1)).write(to: root.appendingPathComponent("manifest.json"))
        try Data(repeating: 0, count: 32).write(to: root.appendingPathComponent("payload.dylib"))
        XCTAssertThrowsError(try PetPackageImporter().inspectDirectory(at: root)) {
            XCTAssertEqual($0 as? PetPackageError, .unsupportedResource("payload.dylib"))
        }

        try FileManager.default.removeItem(at: root.appendingPathComponent("payload.dylib"))
        try Data(repeating: 0, count: 32).write(to: root.appendingPathComponent("unused.jpg"))
        var importer = PetPackageImporter()
        importer.maximumPackageBytes = 16
        XCTAssertThrowsError(try importer.inspectDirectory(at: root)) {
            XCTAssertEqual($0 as? PetPackageError, .packageTooLarge)
        }
    }
}
