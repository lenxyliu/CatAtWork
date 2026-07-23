import Foundation

public enum PetBehaviorPriority: Int, Comparable, Codable, Sendable {
    case idle = 0
    case autonomous = 10
    case systemEvent = 20
    case directInteraction = 30
    case grabbedOrThrown = 40

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PetEvent: Equatable, Sendable {
    case tick(Date)
    case pointerApproached
    case pointerWalkLeft
    case pointerWalkRight
    case pointerChaseLeft
    case pointerChaseRight
    case shooLeft
    case shooRight
    case autonomousWalkLeft
    case autonomousWalkRight
    case autonomousRunLeft
    case autonomousRunRight
    case autonomousMicro(String)
    case autonomousAction(String)
    case clicked
    case petting
    case earsPetted(pointerOnLeft: Bool)
    case chinPetted(pointerOnLeft: Bool)
    case backPetted(pointerOnLeft: Bool)
    case bellyPetted(pointerOnLeft: Bool)
    case previewAnimation(String)
    case animationFinished(String)
    case grabbed
    case thrown(velocity: Vector2D)
    case landed
    case userBecameActive
    case userBecameIdle
    case workspaceCategory(WorkspaceCategory)
    case chargingChanged(Bool)
    case batteryLevelChanged(Double)
    case networkChanged(Bool)
    case mediaPlaybackChanged(Bool)
    case volumeChanged(Double)
    case timePeriodChanged(Int)
    case lockChanged(Bool)
    case spaceChanged
    case wake
    case sleep
}

public enum WorkspaceCategory: String, Codable, Sendable {
    case work, browsing, media, meeting, game, privateOrUnknown
}

public struct ActiveBehavior: Equatable, Sendable {
    public var animation: String
    public var priority: PetBehaviorPriority
    public var expiresAt: Date?
    /// Intended ownership duration once the action actually starts. Queued
    /// actions use this to avoid expiring while a pose bridge is still playing.
    public var duration: TimeInterval?

    public init(animation: String, priority: PetBehaviorPriority, expiresAt: Date? = nil,
                duration: TimeInterval? = nil) {
        self.animation = animation
        self.priority = priority
        self.expiresAt = expiresAt
        self.duration = duration
    }
}

public struct BehaviorEngine: Sendable {
    private var coordinator = ActionCoordinator()
    private var isGrabbed = false
    private var currentPose: PetPose = .seated
    private let poseRouter = PoseTransitionRouter()

    public init() {}

    public var active: ActiveBehavior { coordinator.active }
    public var lastDecision: ActionDecision { coordinator.lastDecision }
    public var queuedActionCount: Int { coordinator.queuedCount }
    public var pose: PetPose { currentPose }

    @discardableResult
    public mutating func handle(_ event: PetEvent, now: Date = .now) -> ActiveBehavior {
        let expiring = coordinator.active
        if coordinator.tick(now: now) == .finished {
            updatePose(after: expiring.animation)
            ensureIdlePose(now: now)
        }

        let request: ActiveBehavior?
        let force: Bool
        switch event {
        case .tick:
            // The pure AutonomyScheduler owns all random timing so tests and
            // diagnostics can reproduce a complete no-input behavior trace.
            force = false
            request = nil
        case .pointerApproached:
            force = false
            request = active.animation == "sleep" ? nil : timed("curious", .directInteraction, seconds: 2.6, now: now)
        case .pointerWalkLeft: force = false; request = timed("walkLeft", .directInteraction, seconds: 0.8, now: now)
        case .pointerWalkRight: force = false; request = timed("walkRight", .directInteraction, seconds: 0.8, now: now)
        case .pointerChaseLeft: force = false; request = timed("runLeft", .directInteraction, seconds: 0.7, now: now)
        case .pointerChaseRight: force = false; request = timed("runRight", .directInteraction, seconds: 0.7, now: now)
        case .shooLeft: force = true; request = timed("runLeft", .directInteraction, seconds: 1.4, now: now)
        case .shooRight: force = true; request = timed("runRight", .directInteraction, seconds: 1.4, now: now)
        case .autonomousWalkLeft: force = false; request = timed("walkLeft", .autonomous, seconds: 0.8, now: now)
        case .autonomousWalkRight: force = false; request = timed("walkRight", .autonomous, seconds: 0.8, now: now)
        case .autonomousRunLeft: force = false; request = timed("runLeft", .autonomous, seconds: 0.8, now: now)
        case .autonomousRunRight: force = false; request = timed("runRight", .autonomous, seconds: 0.8, now: now)
        case .autonomousMicro(let animation): force = false; request = timed(animation, .autonomous, seconds: 3, now: now)
        case .autonomousAction(let animation):
            force = false
            request = timed(animation, .autonomous, seconds: animation == "sleep" ? 45 : 4.5, now: now)
        case .clicked:
            force = active.animation == "sleep"
            request = timed(active.animation == "sleep" ? "wakeUp" : "wave", .directInteraction, seconds: 3, now: now)
        case .petting: force = false; request = timed("petting", .directInteraction, seconds: 2.6, now: now)
        case .earsPetted: force = false; request = timed("earPet", .directInteraction, seconds: 3, now: now)
        case .chinPetted: force = false; request = timed("chinPet", .directInteraction, seconds: 3, now: now)
        case .backPetted: force = false; request = timed("backPet", .directInteraction, seconds: 3, now: now)
        case .bellyPetted: force = false; request = timed("bellyPet", .directInteraction, seconds: 3.2, now: now)
        case .previewAnimation(let animation): force = true; request = timed(animation, .directInteraction, seconds: 4.5, now: now)
        case .animationFinished(let animation):
            force = false; request = nil
            if !isGrabbed {
                updatePose(after: animation)
                _ = coordinator.finish(animation, now: now)
                ensureIdlePose(now: now)
            }
        case .grabbed:
            isGrabbed = true; force = true
            request = ActiveBehavior(animation: "pickup", priority: .grabbedOrThrown)
        case .thrown:
            isGrabbed = false; force = true
            request = ActiveBehavior(animation: "thrown", priority: .grabbedOrThrown)
        case .landed:
            isGrabbed = false
            force = true
            request = timed("landing", .grabbedOrThrown, seconds: 3, now: now)
        case .networkChanged(let connected):
            force = !connected
            request = connected ? nil : timed("failed", .systemEvent, seconds: 3, now: now)
        case .batteryLevelChanged(let level):
            force = level <= 0.15
            request = level <= 0.15 ? timed("waiting", .systemEvent, seconds: 4, now: now) : nil
        case .lockChanged(let locked):
            force = true
            request = locked ? ActiveBehavior(animation: "sleep", priority: .systemEvent)
                             : timed("wakeUp", .systemEvent, seconds: 3, now: now)
        case .wake:
            force = true; request = timed("wakeUp", .systemEvent, seconds: 3, now: now)
        case .sleep:
            force = true; request = ActiveBehavior(animation: "sleep", priority: .systemEvent)
        case .userBecameActive, .userBecameIdle, .workspaceCategory, .chargingChanged,
             .mediaPlaybackChanged, .volumeChanged, .timePeriodChanged, .spaceChanged:
            // Context changes feed future behavior weighting; they do not seize
            // the body from an action already in progress.
            force = false; request = nil
        }

        if let request { submit(request, force: force, now: now) }
        return active
    }

    private func timed(_ animation: String, _ priority: PetBehaviorPriority, seconds: TimeInterval, now: Date) -> ActiveBehavior {
        ActiveBehavior(animation: animation, priority: priority,
                       expiresAt: now.addingTimeInterval(seconds), duration: seconds)
    }

    private mutating func submit(_ request: ActiveBehavior, force: Bool, now: Date) {
        guard !force else {
            _ = coordinator.submit(request, force: true, now: now)
            return
        }

        let expectedPose = poseRouter.endPose(for: coordinator.active.animation) ?? currentPose
        if let targetPose = poseRouter.startPose(for: request.animation), targetPose != expectedPose {
            for transition in poseRouter.transitions(from: expectedPose, to: targetPose) {
                let bridge = ActiveBehavior(animation: transition, priority: request.priority)
                _ = coordinator.submit(bridge, now: now)
            }
        }
        _ = coordinator.submit(request, now: now)
    }

    private mutating func updatePose(after animation: String) {
        if let endPose = poseRouter.endPose(for: animation) { currentPose = endPose }
    }

    private mutating func ensureIdlePose(now: Date) {
        guard coordinator.active.animation == "idle", currentPose != .seated else { return }
        guard let transition = poseRouter.transitions(from: currentPose, to: .seated).first else { return }
        _ = coordinator.submit(ActiveBehavior(animation: transition, priority: .autonomous), now: now)
    }
}
