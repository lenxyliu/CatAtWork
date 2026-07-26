import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
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

private func canonicalDigest(_ character: Character = "a") -> String {
    "sha256:" + String(repeating: String(character), count: 64)
}

private func canonicalFrame(_ index: Int) -> PetFrame {
    let digest = canonicalDigest(index == 0 ? "a" : "b")
    return PetFrame(
        image: "atlases/idle.png",
        sourceSize: .init(width: 64, height: 64),
        trimRect: .init(x: 20, y: 20, width: index == 0 ? 25 : 35, height: 33),
        textureRect: .init(x: index * 68, y: 0, width: 64, height: 64),
        collisionRect: .init(x: 20, y: 20, width: 25, height: 33),
        pivot: .init(x: 0.5, y: 0.8125),
        duration: 1.0 / 12.0,
        rootAnchor: .init(x: 32, y: 52),
        supportAnchors: [
            .init(id: "leftHindFoot", point: .init(x: 27, y: 52), contact: true),
            .init(id: "rightHindFoot", point: .init(x: 37, y: 52), contact: true),
        ],
        sourcePixelSHA256: digest,
        atlasPixelSHA256: digest
    )
}

private func canonicalManifest() -> PetManifest {
    let frames = [canonicalFrame(0), canonicalFrame(1)]
    let landmarks = [
        "leftEyeCenter", "rightEyeCenter", "leftEarRoot", "rightEarRoot",
        "nose", "mouth", "shoulder", "hip", "leftForelimbJoint",
        "rightForelimbJoint", "leftHindlimbJoint", "rightHindlimbJoint",
        "tailRoot",
    ].reduce(into: [String: PixelPoint]()) {
        $0[$1] = .init(x: 32, y: 32)
    }
    let animation = PetAnimation(
        id: "idle",
        loopMode: .loop,
        startPose: PetPose.seated.rawValue,
        endPose: PetPose.seated.rawValue,
        startPoseSignature: .init(
            pose: PetPose.seated.rawValue,
            frameIndex: 0,
            pixelSHA256: frames[0].atlasPixelSHA256!,
            rootAnchor: frames[0].rootAnchor!,
            supportAnchorIDs: ["leftHindFoot", "rightHindFoot"]
        ),
        endPoseSignature: .init(
            pose: PetPose.seated.rawValue,
            frameIndex: 1,
            pixelSHA256: frames[1].atlasPixelSHA256!,
            rootAnchor: frames[1].rootAnchor!,
            supportAnchorIDs: ["leftHindFoot", "rightHindFoot"]
        ),
        frames: frames
    )
    return PetManifest(
        formatVersion: 2,
        id: "canonical-cat",
        displayName: "Canonical Cat",
        author: "CatAtWork tests",
        description: "Synthetic format-2 manifest.",
        assetVersion: "fixture-v2",
        pixelsPerBodyUnit: 220,
        authoredCanvas: .init(width: 64, height: 64, safeMargin: 4),
        colorSpace: .canonicalSRGB,
        componentPolicy: .init(),
        identityRig: .init(
            views: [
                .init(
                    id: "front",
                    referenceAnimation: "idle",
                    referenceFrame: 0,
                    landmarks: landmarks,
                    contours: [
                        "headOutline": [
                            .init(x: 20, y: 20),
                            .init(x: 44, y: 20),
                            .init(x: 32, y: 40),
                        ],
                        "faceMaskOutline": [
                            .init(x: 24, y: 24),
                            .init(x: 40, y: 24),
                            .init(x: 32, y: 37),
                        ],
                    ],
                    materialROIs: [
                        "coat": .init(x: 26, y: 39, width: 12, height: 9),
                        "faceMask": .init(x: 25, y: 24, width: 14, height: 12),
                    ]
                ),
            ]
        ),
        animations: [animation],
        lookDirections: []
    )
}

private func writeCanonicalAtlas(
    to url: URL,
    disconnectedSecondFrame: Bool
) throws {
    let width = 132
    let height = 64
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    func fill(_ rect: PixelRect, color: (UInt8, UInt8, UInt8, UInt8)) {
        for y in rect.y..<(rect.y + rect.height) {
            for x in rect.x..<(rect.x + rect.width) {
                let index = (y * width + x) * 4
                pixels[index] = color.0
                pixels[index + 1] = color.1
                pixels[index + 2] = color.2
                pixels[index + 3] = color.3
            }
        }
    }
    fill(.init(x: 20, y: 20, width: 25, height: 33), color: (180, 120, 95, 255))
    fill(.init(x: 88, y: 20, width: 25, height: 33), color: (180, 120, 95, 255))
    fill(.init(x: 112, y: 44, width: 11, height: 4), color: (180, 120, 95, 255))
    if disconnectedSecondFrame {
        fill(.init(x: 76, y: 8, width: 4, height: 4), color: (30, 30, 30, 255))
    }
    let data = Data(pixels)
    guard let provider = CGDataProvider(data: data as CFData),
          let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let image = CGImage(
              width: width,
              height: height,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
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

    func testAcceptsCanonicalFormat2AndKeepsSilhouetteOutOfScaleAndRoot() throws {
        let value = canonicalManifest()
        try PetManifestValidator().validate(value, requireHighFrame: false)
        let frames = value.animations[0].frames

        XCTAssertNotEqual(frames[0].trimRect, frames[1].trimRect)
        XCTAssertEqual(frames[0].sourceSize, frames[1].sourceSize)
        XCTAssertEqual(frames[0].rootAnchor, frames[1].rootAnchor)
        XCTAssertEqual(frames[0].pivot, frames[1].pivot)
        XCTAssertNil(frames[0].bodyScale)
        XCTAssertEqual(
            PetPackageContract(manifest: value).compatibilityMode,
            .canonicalFormat2
        )
    }

    func testCanonicalFormat2RejectsMissingAnchorsAndHiddenResize() {
        var value = canonicalManifest()
        value.animations[0].frames[0].rootAnchor = nil
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidAnchor(animation: "idle", frame: 0))
        }

        value = canonicalManifest()
        value.animations[0].frames[0].bodyScale = 1.01
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual(
                $0 as? PetManifestIssue,
                .invalidCanonicalMetadata("idle.bodyScale")
            )
        }
    }

    func testCanonicalFormat2RejectsColorDigestAndEndpointMismatch() {
        var value = canonicalManifest()
        value.colorSpace?.name = "DisplayP3"
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual(
                $0 as? PetManifestIssue,
                .invalidCanonicalMetadata("colorSpace")
            )
        }

        value = canonicalManifest()
        value.animations[0].frames[1].atlasPixelSHA256 = canonicalDigest("c")
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual(
                $0 as? PetManifestIssue,
                .invalidCanonicalMetadata("idle.pixelSHA256")
            )
        }

        value = canonicalManifest()
        value.animations[0].endPoseSignature?.pose = PetPose.standing.rawValue
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidEndpointSignature("idle"))
        }
    }

    func testCanonicalFormat2RejectsIncompleteIdentityAndComponentReview() {
        var value = canonicalManifest()
        value.identityRig?.views[0].landmarks["tailRoot"] = nil
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidIdentityRig("front"))
        }

        value = canonicalManifest()
        value.componentPolicy?.exceptions = [
            .init(
                reviewId: "review-1",
                issue: "#16",
                owner: "maintainers",
                reviewedBy: "B3 review",
                reason: "Synthetic semantic component.",
                animation: "idle",
                frames: [1],
                maximumSecondaryComponents: 1,
                maximumSecondaryArea: 16
            ),
        ]
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual($0 as? PetManifestIssue, .invalidComponentPolicy("review-1"))
        }
    }

    func testLegacyFormat1RemainsReadOnlyCompatibleWithoutCanonicalMetadata() throws {
        let value = manifest()
        try PetManifestValidator().validate(value, requireHighFrame: false)
        XCTAssertNil(value.authoredCanvas)
        XCTAssertNil(value.identityRig)
        XCTAssertEqual(
            PetPackageContract(manifest: value).compatibilityMode,
            .legacyFormat1
        )
    }

    func testFormat2NeverSynthesizesMissingCanonicalMetadata() {
        var value = manifest()
        value.formatVersion = 2
        XCTAssertThrowsError(try PetManifestValidator().validate(value, requireHighFrame: false)) {
            XCTAssertEqual(
                $0 as? PetManifestIssue,
                .missingCanonicalMetadata("authoredCanvas")
            )
        }
    }

    func testImporterAcceptsCanonicalContentAndRejectsDisconnectedPixels() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let atlases = root.appendingPathComponent("atlases", isDirectory: true)
        try FileManager.default.createDirectory(
            at: atlases,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let manifestData = try JSONEncoder().encode(canonicalManifest())
        try manifestData.write(to: root.appendingPathComponent("manifest.json"))
        let atlas = atlases.appendingPathComponent("idle.png")

        try writeCanonicalAtlas(to: atlas, disconnectedSecondFrame: false)
        let imported = try PetPackageImporter().inspectDirectory(at: root)
        XCTAssertEqual(imported.manifest.formatVersion, 2)
        XCTAssertEqual(
            PetPackageContract(manifest: imported.manifest).compatibilityMode,
            .canonicalFormat2
        )

        try writeCanonicalAtlas(to: atlas, disconnectedSecondFrame: true)
        XCTAssertThrowsError(try PetPackageImporter().inspectDirectory(at: root)) {
            XCTAssertEqual(
                $0 as? PetPackageError,
                .canonicalContentInvalid("idle frame 1: disconnected components")
            )
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
