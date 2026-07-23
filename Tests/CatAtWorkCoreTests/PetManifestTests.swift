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
