import Foundation

/// Immutable runtime semantics compiled from one validated package manifest.
/// A nil capability set is used only by the built-in compatibility contract
/// so standalone BehaviorEngine tests retain the complete legacy vocabulary.
public struct PetPackageContract: Sendable {
    public static let referencePixelsPerBodyUnit = 220.0

    private static let semanticFallbacks: [String: [String]] = [
        "runLeft": ["walkLeft"],
        "runRight": ["walkRight"],
        "earPet": ["petting", "curious"],
        "chinPet": ["petting", "curious"],
        "backPet": ["petting", "curious"],
        "bellyPet": ["petting", "curious"],
        "wave": ["curious"],
        "wakeUp": ["getUp"],
        "getUp": ["wakeUp"],
    ]

    private let animationIDs: Set<String>?
    private let nextAnimations: [String: String]
    public let poseRouter: PoseTransitionRouter
    public let pixelsPerBodyUnit: Double

    /// Complete legacy contract used when no package has been published yet.
    public static let standard = PetPackageContract()

    public init() {
        animationIDs = nil
        nextAnimations = [:]
        poseRouter = PoseTransitionRouter()
        pixelsPerBodyUnit = Self.referencePixelsPerBodyUnit
    }

    public init(manifest: PetManifest) {
        animationIDs = Set(manifest.animations.map(\.id))
        var compiledNext: [String: String] = [:]
        for animation in manifest.animations {
            if let nextAnimation = animation.nextAnimation {
                compiledNext[animation.id] = nextAnimation
            }
        }
        nextAnimations = compiledNext
        poseRouter = PoseTransitionRouter(manifest: manifest)
        pixelsPerBodyUnit = manifest.pixelsPerBodyUnit
    }

    /// Resolves an exact capability first, then the documented semantic
    /// alternatives. Nil means the behavior must be suppressed.
    public func resolvedAnimationID(for requestedID: String) -> String? {
        if isAvailable(requestedID) { return requestedID }
        return Self.semanticFallbacks[requestedID]?.first(where: isAvailable)
    }

    public func nextAnimation(after animationID: String) -> String? {
        nextAnimations[animationID]
    }

    public var supportsPhysicalInteraction: Bool {
        ["pickup", "thrown", "landing"].allSatisfy(isAvailable)
    }

    public var supportsPointerLocomotion: Bool {
        resolvedAnimationID(for: "walkLeft") != nil &&
            resolvedAnimationID(for: "walkRight") != nil
    }

    public var initialPose: PetPose {
        poseRouter.endPose(for: "idle") ?? poseRouter.startPose(for: "idle") ?? .seated
    }

    /// Converts authored source pixels to the established desktop scale. The
    /// default package (220 px/body unit) remains exactly backward compatible.
    public func canvasScale(userScale: Double) -> Double {
        let safeUserScale = userScale.isFinite && userScale > 0 ? userScale : 0.45
        let safeDensity = pixelsPerBodyUnit.isFinite && pixelsPerBodyUnit > 0
            ? pixelsPerBodyUnit
            : Self.referencePixelsPerBodyUnit
        return safeUserScale * Self.referencePixelsPerBodyUnit / safeDensity
    }

    private func isAvailable(_ animationID: String) -> Bool {
        animationIDs?.contains(animationID) ?? true
    }
}

public extension PetFrame {
    /// Transparent pixels outside trim bounds never become an implicit input
    /// surface merely because explicit collision metadata is absent.
    var interactionRect: PixelRect { collisionRect ?? trimRect }
}

/// Core-owned portion of a newly published package session. Construction
/// never accepts prior transient state, which makes reset-by-replacement the
/// only possible behavior for the queue, player and physics.
public struct PetSessionCoreState: Sendable {
    public let generation: UInt64
    public var behavior: BehaviorEngine
    public var player: AnimationPlayer
    public var physics: PetPhysics

    public init(
        replacing generation: UInt64,
        contract: PetPackageContract,
        position: Vector2D
    ) {
        self.generation = generation &+ 1
        behavior = BehaviorEngine(contract: contract)
        player = AnimationPlayer()
        physics = PetPhysics(position: position)
    }
}
