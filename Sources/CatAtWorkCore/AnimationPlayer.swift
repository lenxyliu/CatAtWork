import Foundation

public struct AnimationPlayer: Sendable {
    public private(set) var animationID: String
    public private(set) var frameIndex: Int = 0
    public private(set) var elapsedInFrame: Double = 0
    public private(set) var completedCycle = false
    private var direction = 1

    public init(animationID: String = "idle") {
        self.animationID = animationID
    }

    public mutating func transition(to animationID: String) {
        guard self.animationID != animationID else { return }
        self.animationID = animationID
        frameIndex = 0
        elapsedInFrame = 0
        direction = 1
        completedCycle = false
    }

    @discardableResult
    public mutating func advance(deltaTime: Double, animation: PetAnimation) -> Int {
        guard !animation.frames.isEmpty else { return 0 }
        completedCycle = false
        var remaining = min(max(deltaTime, 0), 0.25)
        while remaining > 0 {
            let duration = animation.frames[frameIndex].duration
            let consumed = min(duration - elapsedInFrame, remaining)
            elapsedInFrame += consumed
            remaining -= consumed
            guard elapsedInFrame + 0.000_001 >= duration else { break }
            elapsedInFrame = 0
            stepIndex(animation: animation)
        }
        return frameIndex
    }

    public func isFinished(animation: PetAnimation) -> Bool {
        animation.loopMode == .once && completedCycle
    }

    private mutating func stepIndex(animation: PetAnimation) {
        switch animation.loopMode {
        case .loop:
            let legacySleepStart = animation.id == "sleep" && animation.frames.count >= 16 ? 8 : 0
            let loopStart = min(max(animation.loopStartFrame ?? legacySleepStart, 0), animation.frames.count - 1)
            if frameIndex == animation.frames.count - 1 {
                // Intro+loop actions (sleep settling and pickup stretching) keep
                // their one-time lead-in but never snap back to frame zero.
                frameIndex = loopStart
            } else {
                frameIndex += 1
            }
        case .once:
            if frameIndex == animation.frames.count - 1 {
                completedCycle = true
            } else {
                frameIndex += 1
            }
        case .pingPong:
            if frameIndex + direction >= animation.frames.count || frameIndex + direction < 0 { direction *= -1 }
            frameIndex = max(0, min(animation.frames.count - 1, frameIndex + direction))
        }
    }
}

public extension PetManifest {
    func animation(named id: String) -> PetAnimation? {
        animations.first { $0.id == id } ?? animations.first { $0.id == "idle" }
    }
}
