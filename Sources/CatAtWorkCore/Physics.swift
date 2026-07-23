import Foundation

public struct Vector2D: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double = 0, y: Double = 0) {
        self.x = x
        self.y = y
    }
}

public enum PetReleaseMode: Equatable, Sendable {
    case placed
    case dropped
    case thrown
}

public enum PetReleasePolicy {
    public static func classify(speed: Double, heightAboveFloor: Double) -> PetReleaseMode {
        if speed >= 320 { return .thrown }
        return heightAboveFloor <= 12 ? .placed : .dropped
    }
}

public struct PetPhysics: Sendable {
    public var position: Vector2D
    public var velocity: Vector2D
    public var gravity: Double
    public var linearDamping: Double
    public var maxSpeed: Double
    public private(set) var lastImpactVelocityY: Double?

    public init(
        position: Vector2D = .init(),
        velocity: Vector2D = .init(),
        gravity: Double = -1_800,
        linearDamping: Double = 0.985,
        maxSpeed: Double = 2_400
    ) {
        self.position = position
        self.velocity = velocity
        self.gravity = gravity
        self.linearDamping = linearDamping
        self.maxSpeed = maxSpeed
        self.lastImpactVelocityY = nil
    }

    public mutating func step(deltaTime rawDelta: Double, floorY: Double, horizontalBounds: ClosedRange<Double>) -> Bool {
        lastImpactVelocityY = nil
        let dt = min(max(rawDelta, 0), 1.0 / 20.0)
        // A resting pet is supported by the floor. Applying gravity to it on
        // every watchdog tick used to manufacture a fresh -90 pt/s impact at
        // 20 Hz, so `.landed` was emitted forever and the animation remained
        // stuck on landing's final frame.
        let wasAirborne = position.y > floorY + 0.5 || velocity.y > 0
        if position.y <= floorY && velocity.y <= 0 {
            position.y = floorY
            velocity.y = 0
        } else {
            velocity.y += gravity * dt
        }
        let speed = hypot(velocity.x, velocity.y)
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            velocity.x *= scale
            velocity.y *= scale
        }
        position.x += velocity.x * dt
        position.y += velocity.y * dt
        velocity.x *= pow(linearDamping, dt * 60)

        if position.x < horizontalBounds.lowerBound {
            position.x = horizontalBounds.lowerBound
            velocity.x = abs(velocity.x) * 0.45
        } else if position.x > horizontalBounds.upperBound {
            position.x = horizontalBounds.upperBound
            velocity.x = -abs(velocity.x) * 0.45
        }

        if position.y <= floorY {
            let impactVelocityY = velocity.y
            let didLand = wasAirborne && impactVelocityY < -80
            position.y = floorY
            velocity.y = 0
            if didLand { lastImpactVelocityY = impactVelocityY }
            return didLand
        }
        return false
    }
}
