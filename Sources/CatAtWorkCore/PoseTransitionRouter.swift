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

    private struct Bridge: Sendable {
        var start: PetPose
        var end: PetPose
        var animation: String
    }

    private static let legacyProfiles: [String: Profile] = {
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

    private let profiles: [String: Profile]
    private let bridges: [Bridge]

    public init() {
        profiles = Self.legacyProfiles
        bridges = Self.makeBridges(profiles: profiles)
    }

    public init(manifest: PetManifest) {
        var compiled: [String: Profile] = [:]
        for animation in manifest.animations {
            let legacy = Self.legacyProfiles[animation.id] ?? Profile(start: .seated, end: .seated)
            let start = animation.startPose.flatMap(PetPose.init(rawValue:)) ?? legacy.start
            let end = animation.endPose.flatMap(PetPose.init(rawValue:)) ?? legacy.end
            compiled[animation.id] = Profile(start: start, end: end)
        }
        profiles = compiled
        bridges = Self.makeBridges(profiles: compiled)
    }

    public func startPose(for animation: String) -> PetPose? { profiles[animation]?.start }
    public func endPose(for animation: String) -> PetPose? { profiles[animation]?.end }

    /// Returns nil when the package has no legal authored bridge path.
    public func transitions(from start: PetPose, to end: PetPose) -> [String]? {
        guard start != end else { return [] }
        var pending: [(pose: PetPose, path: [String])] = [(start, [])]
        var visited: Set<PetPose> = [start]
        while !pending.isEmpty {
            let current = pending.removeFirst()
            for bridge in bridges where bridge.start == current.pose {
                let path = current.path + [bridge.animation]
                if bridge.end == end { return path }
                if visited.insert(bridge.end).inserted {
                    pending.append((bridge.end, path))
                }
            }
        }
        return nil
    }

    public static func defaultStartPose(for animation: String) -> PetPose {
        legacyProfiles[animation]?.start ?? .seated
    }

    public static func defaultEndPose(for animation: String) -> PetPose {
        legacyProfiles[animation]?.end ?? defaultStartPose(for: animation)
    }

    private static func makeBridges(profiles: [String: Profile]) -> [Bridge] {
        let candidates: [(PetPose, PetPose, [String])] = [
            (.seated, .standing, ["sitToStand"]),
            (.standing, .seated, ["standToSit"]),
            (.seated, .lying, ["lieDown"]),
            (.lying, .seated, ["getUp", "wakeUp"]),
        ]
        return candidates.compactMap { start, end, animationIDs in
            guard let animation = animationIDs.first(where: {
                profiles[$0]?.start == start && profiles[$0]?.end == end
            }) else { return nil }
            return Bridge(start: start, end: end, animation: animation)
        }
    }
}
