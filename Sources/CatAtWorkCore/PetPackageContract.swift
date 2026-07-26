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
    public let compatibilityMode: PetPackageCompatibilityMode

    /// Complete legacy contract used when no package has been published yet.
    public static let standard = PetPackageContract()

    public init() {
        animationIDs = nil
        nextAnimations = [:]
        poseRouter = PoseTransitionRouter()
        pixelsPerBodyUnit = Self.referencePixelsPerBodyUnit
        compatibilityMode = .legacyFormat1
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
        compatibilityMode = manifest.formatVersion == 2 ? .canonicalFormat2 : .legacyFormat1
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

/// The authoritative, platform-neutral state for one published pet session.
/// Construction never accepts prior transient state, which makes
/// reset-by-replacement the only possible behavior for the queue, player and
/// physics. AppKit adapters translate events and apply effects around this
/// value; they do not own another copy of these fields.
public struct PetRuntimeState: Sendable {
    public let generation: UInt64
    public private(set) var contract: PetPackageContract
    public private(set) var behavior: BehaviorEngine
    public private(set) var player: AnimationPlayer
    public private(set) var physics: PetPhysics

    public init(
        replacing generation: UInt64,
        contract: PetPackageContract,
        position: Vector2D
    ) {
        self.generation = generation &+ 1
        self.contract = contract
        behavior = BehaviorEngine(contract: contract)
        player = AnimationPlayer()
        physics = PetPhysics(position: position)
    }

    /// Publish a validated contract before the next session replacement. The
    /// behavior engine is rebuilt by the replacement initializer so it can
    /// never retain the prior package's capabilities.
    public mutating func setContract(_ contract: PetPackageContract) {
        self.contract = contract
    }

    public mutating func setPosition(_ position: Vector2D) {
        physics.position = position
    }

    public mutating func setPositionX(_ x: Double) {
        physics.position.x = x
    }

    public mutating func setPositionY(_ y: Double) {
        physics.position.y = y
    }

    public mutating func setVelocity(_ velocity: Vector2D) {
        physics.velocity = velocity
    }

    public mutating func setHorizontalVelocity(_ velocity: Double) {
        physics.velocity.x = velocity
    }

    public mutating func blendHorizontalVelocity(toward target: Double, factor: Double) {
        physics.velocity.x += (target - physics.velocity.x) * factor
    }

    public mutating func multiplyHorizontalVelocity(by factor: Double) {
        physics.velocity.x *= factor
    }

    public mutating func restartAnimation(ifCurrent animationID: String) {
        guard player.animationID == animationID else { return }
        player.restart()
    }

    /// Reduce one external event through the deterministic behavior engine.
    @discardableResult
    public mutating func reduce(_ event: PetEvent, now: Date = .now) -> ActiveBehavior {
        behavior.handle(event, now: now)
    }

    /// Advance the selected animation and return its identifier when a
    /// one-shot animation completed. The caller can then reduce
    /// `animationFinished` without reaching into the player transition rules.
    @discardableResult
    public mutating func synchronizeAnimation(
        with manifest: PetManifest,
        deltaTime: Double
    ) -> String? {
        player.transition(to: behavior.active.animation)
        guard let animation = manifest.animation(named: player.animationID) else { return nil }
        _ = player.advance(deltaTime: deltaTime, animation: animation)
        return player.isFinished(animation: animation) ? animation.id : nil
    }

    /// Advance physics for the current session and report a meaningful landing
    /// impact to the adapter.
    @discardableResult
    public mutating func stepPhysics(
        deltaTime: Double,
        floorY: Double,
        horizontalBounds: ClosedRange<Double>
    ) -> Bool {
        physics.step(deltaTime: deltaTime, floorY: floorY, horizontalBounds: horizontalBounds)
    }
}

/// Compatibility name retained for callers and historical tests. New code
/// should use `PetRuntimeState` so the single-state invariant is explicit.
public typealias PetSessionCoreState = PetRuntimeState
