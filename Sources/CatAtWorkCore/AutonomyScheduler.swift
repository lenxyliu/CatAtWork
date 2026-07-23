import Foundation

public enum AutonomyCue: Equatable, Sendable {
    case micro(String)
    case roam(run: Bool, moveRight: Bool)
    case major(String)
}

/// Coarse, privacy-preserving context that changes only future autonomous
/// choices. It never contains a window title, key, pointer coordinate, song,
/// or document name.
public struct AutonomyContext: Equatable, Sendable {
    public var userIsActive: Bool
    public var workspace: WorkspaceCategory
    public var mediaIsPlaying: Bool
    public var isCharging: Bool
    public var outputVolume: Double
    public var hour: Int

    public init(
        userIsActive: Bool = true,
        workspace: WorkspaceCategory = .privateOrUnknown,
        mediaIsPlaying: Bool = false,
        isCharging: Bool = false,
        outputVolume: Double = 0.5,
        hour: Int = 12
    ) {
        self.userIsActive = userIsActive
        self.workspace = workspace
        self.mediaIsPlaying = mediaIsPlaying
        self.isCharging = isCharging
        self.outputVolume = min(max(outputVolume, 0), 1)
        self.hour = hour
    }
}

/// A deterministic, clock-driven source of autonomous intentions. The same
/// seed and timestamps always produce the same trace, while the app chooses a
/// new seed per launch for natural variety.
public struct AutonomyScheduler: Sendable {
    private var random: SplitMix64
    private var nextMicroAt: TimeInterval
    private var nextRoamAt: TimeInterval
    private var nextMajorAt: TimeInterval
    private var nextMicroIsEar = true
    private var majorCount = 0

    public init(startTime: TimeInterval = 0, seed: UInt64 = 0xCA7A_7A0B) {
        var generator = SplitMix64(state: seed)
        nextMicroAt = startTime + 2 + generator.unit() * 3
        nextRoamAt = startTime + 15 + generator.unit() * 20
        nextMajorAt = startTime + 8 + generator.unit() * 10
        random = generator
    }

    /// Emits at most one body cue. When the coordinator is busy, due cues wait
    /// instead of being lost or fighting the active animation.
    public mutating func nextCue(
        at time: TimeInterval,
        isAvailable: Bool,
        context: AutonomyContext = .init()
    ) -> AutonomyCue? {
        guard isAvailable else { return nil }

        var kind: Int?
        var earliest = TimeInterval.greatestFiniteMagnitude
        if nextMicroAt <= time {
            kind = 0
            earliest = nextMicroAt
        }
        if nextMajorAt <= time, nextMajorAt < earliest {
            kind = 1
            earliest = nextMajorAt
        }
        if nextRoamAt <= time, nextRoamAt < earliest {
            kind = 2
        }
        guard let kind else { return nil }

        switch kind {
        case 0:
            let animation = nextMicroIsEar ? "idleEar" : "idleTail"
            nextMicroIsEar.toggle()
            nextMicroAt = time + 2 + random.unit() * 3
            return .micro(animation)
        case 1:
            majorCount += 1
            let animation: String
            let isRestTime = context.hour >= 22 || context.hour < 7
            let sleepInterval = (!context.userIsActive || isRestTime) ? 2 : 3
            if majorCount % sleepInterval == 0 {
                animation = "sleep"
            } else {
                let choices: [String]
                if context.workspace == .meeting {
                    // Meetings keep the cat quiet: no jump, roll, or celebratory
                    // motion, but it still breathes, works, and grooms.
                    choices = context.userIsActive
                        ? ["working", "working", "groom", "waiting"]
                        : ["groom", "waiting", "waiting"]
                } else if context.mediaIsPlaying && context.outputVolume <= 0.05 {
                    choices = ["working", "groom", "waiting"]
                } else if context.mediaIsPlaying && context.outputVolume >= 0.65 {
                    choices = ["happy", "happy", "happy", "bellyRoll", "groom"]
                } else if context.mediaIsPlaying {
                    choices = ["happy", "happy", "bellyRoll", "groom"]
                } else if context.userIsActive && context.workspace == .work {
                    choices = ["working", "working", "working", "groom", "happy"]
                } else if !context.userIsActive {
                    choices = ["groom", "groom", "waiting", "bellyRoll"]
                } else if context.isCharging {
                    choices = ["happy", "working", "groom", "jump"]
                } else {
                    choices = ["groom", "jump", "bellyRoll", "waiting", "happy"]
                }
                animation = choices[random.index(upperBound: choices.count)]
            }
            nextMajorAt = time + 8 + random.unit() * 10
            return .major(animation)
        default:
            let cue = AutonomyCue.roam(
                run: random.unit() < 0.35,
                moveRight: random.unit() < 0.5
            )
            nextRoamAt = time + 15 + random.unit() * 20
            return cue
        }
    }
}

private struct SplitMix64: Sendable {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func index(upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}
