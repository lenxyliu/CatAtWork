import Foundation

public enum PetPose: String, Codable, Hashable, Sendable {
    case seated
    case standing
    case lying
    case hanging
    case airborne
}

/// Defines the body's small pose graph independently of behavioral priority.
/// It lets the coordinator queue a real authored bridge instead of snapping
/// between incompatible first/last frames.
public struct PoseTransitionRouter: Sendable {
    private struct Profile: Sendable {
        var start: PetPose
        var end: PetPose
    }

    private static let profiles: [String: Profile] = {
        var values: [String: Profile] = [:]
        func add(_ ids: [String], _ start: PetPose, _ end: PetPose) {
            for id in ids { values[id] = Profile(start: start, end: end) }
        }
        add(["idle", "idleEar", "idleTail", "groom", "wave", "petting", "earPet", "chinPet",
             "backPet", "bellyPet", "bellyRoll", "jump", "curious", "working", "waiting",
             "happy", "startled", "failed"], .seated, .seated)
        add(["walkLeft", "walkRight", "runLeft", "runRight"], .standing, .standing)
        add(["sitToStand"], .seated, .standing)
        add(["standToSit"], .standing, .seated)
        add(["lieDown"], .seated, .lying)
        add(["getUp", "wakeUp"], .lying, .seated)
        add(["sleep"], .lying, .lying)
        add(["pickup"], .seated, .hanging)
        add(["thrown"], .airborne, .airborne)
        add(["landing"], .airborne, .seated)
        return values
    }()

    public init() {}

    public func startPose(for animation: String) -> PetPose? { Self.profiles[animation]?.start }
    public func endPose(for animation: String) -> PetPose? { Self.profiles[animation]?.end }

    public func transitions(from start: PetPose, to end: PetPose) -> [String] {
        guard start != end else { return [] }
        return switch (start, end) {
        case (.seated, .standing): ["sitToStand"]
        case (.standing, .seated): ["standToSit"]
        case (.seated, .lying): ["lieDown"]
        case (.lying, .seated): ["getUp"]
        case (.standing, .lying): ["standToSit", "lieDown"]
        case (.lying, .standing): ["getUp", "sitToStand"]
        default: []
        }
    }
}
