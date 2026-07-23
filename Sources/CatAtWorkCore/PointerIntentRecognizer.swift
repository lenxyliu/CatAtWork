import CoreGraphics
import Foundation

public enum PointerBodyRegion: String, Equatable, Sendable {
    case outside, ears, chin, back, belly
}

public enum RecognizedPointerIntent: Equatable, Sendable {
    case hover(PointerBodyRegion, pointerOnLeft: Bool)
    case pet(PointerBodyRegion, pointerOnLeft: Bool)
    case shoo(moveRight: Bool)
}

public struct PointerIntentRecognizer: Sendable {
    private var region: PointerBodyRegion = .outside
    private var enteredAt: CFTimeInterval = 0
    private var hoverCooldownUntil: CFTimeInterval = 0
    private var hoverIssued = false
    private var lastPoint: CGPoint?
    private var lastTime: CFTimeInterval = 0
    private var lastDirection = 0
    private var reversals = 0
    private var fastReversals = 0
    private var distance: CGFloat = 0

    public init() {}

    public mutating func ingest(point: CGPoint, at now: CFTimeInterval, region newRegion: PointerBodyRegion,
                                pointerOnLeft: Bool) -> RecognizedPointerIntent? {
        guard newRegion != .outside else {
            reset(region: .outside, point: point, now: now)
            return nil
        }
        if newRegion != region { reset(region: newRegion, point: point, now: now) }

        let dx = point.x - (lastPoint?.x ?? point.x)
        let dy = point.y - (lastPoint?.y ?? point.y)
        let dt = max(now - lastTime, 1.0 / 240.0)
        let sampleDistance = hypot(dx, dy)
        let speed = sampleDistance / dt
        distance += sampleDistance
        if abs(dx) >= 3 {
            let direction = dx > 0 ? 1 : -1
            if lastDirection != 0, direction != lastDirection {
                reversals += 1
                if speed >= 900 { fastReversals += 1 }
            }
            lastDirection = direction
        }
        lastPoint = point
        lastTime = now

        if fastReversals >= 2 {
            let moveRight = dx >= 0
            reset(region: newRegion, point: point, now: now)
            return .shoo(moveRight: moveRight)
        }
        if reversals >= 2, distance >= 90 {
            reset(region: newRegion, point: point, now: now)
            return .pet(newRegion, pointerOnLeft: pointerOnLeft)
        }
        if !hoverIssued, now - enteredAt >= 0.30, now >= hoverCooldownUntil {
            hoverIssued = true
            hoverCooldownUntil = now + 8
            return .hover(newRegion, pointerOnLeft: pointerOnLeft)
        }
        return nil
    }

    private mutating func reset(region: PointerBodyRegion, point: CGPoint, now: CFTimeInterval) {
        self.region = region
        enteredAt = now
        hoverIssued = false
        lastPoint = point
        lastTime = now
        lastDirection = 0
        reversals = 0
        fastReversals = 0
        distance = 0
    }
}
