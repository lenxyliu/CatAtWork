import Foundation

public enum ActionDecision: String, Equatable, Sendable {
    case started
    case queued
    case refreshed
    case forced
    case finished
    case ignoredDuplicate
    case ignoredWhilePhysical
    case noChange
}

/// Serializes body animation ownership. Eye/head gaze is intentionally not
/// represented here: it is a render-layer concern and never owns the body.
public struct ActionCoordinator: Sendable {
    public private(set) var active = ActiveBehavior(animation: "idle", priority: .idle)
    public private(set) var lastDecision: ActionDecision = .noChange
    private var queue: [(sequence: UInt64, action: ActiveBehavior)] = []
    private var sequence: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func submit(_ action: ActiveBehavior, force: Bool = false, now: Date = .now) -> ActionDecision {
        guard action.animation != "idle" || active.priority == .idle else {
            lastDecision = .ignoredDuplicate
            return lastDecision
        }

        if active.animation == action.animation {
            if let duration = action.duration {
                let expiry = now.addingTimeInterval(duration)
                active.duration = duration
                active.expiresAt = max(active.expiresAt ?? expiry, expiry)
                lastDecision = .refreshed
            } else if let expiry = action.expiresAt {
                active.expiresAt = max(active.expiresAt ?? expiry, expiry)
                lastDecision = .refreshed
            } else {
                lastDecision = .ignoredDuplicate
            }
            return lastDecision
        }

        if force {
            // A system wake/sleep reaction must never tear the cat out of the
            // user's hand. Physical grab/throw ownership is released only by
            // the corresponding physical transition.
            if active.priority == .grabbedOrThrown, action.priority < active.priority {
                lastDecision = .ignoredDuplicate
                return lastDecision
            }
            queue.removeAll()
            active = activated(action, now: now)
            lastDecision = .forced
            return lastDecision
        }

        // Pointer/system intentions sampled while the cat is held, airborne or
        // visibly recovering from impact are stale by the time that physical
        // chain completes. Queuing them caused the cat to finish landing in a
        // seated pose and immediately snap back into an unrelated crouch or
        // side-on action. Physical ownership discards these lower-priority
        // requests; fresh input can be recognized after recovery.
        if active.priority == .grabbedOrThrown {
            lastDecision = .ignoredWhilePhysical
            return lastDecision
        }

        if active.priority == .idle {
            active = activated(action, now: now)
            lastDecision = .started
            return lastDecision
        }

        if let index = queue.firstIndex(where: { $0.action.animation == action.animation }) {
            if let expiry = action.expiresAt {
                queue[index].action.expiresAt = max(queue[index].action.expiresAt ?? expiry, expiry)
            }
            lastDecision = .ignoredDuplicate
            return lastDecision
        }

        sequence &+= 1
        queue.append((sequence, action))
        if queue.count > 12 { queue.removeFirst(queue.count - 12) }
        lastDecision = .queued
        return lastDecision
    }

    @discardableResult
    public mutating func finish(_ animation: String, now: Date = .now) -> ActionDecision {
        guard active.animation == animation else {
            lastDecision = .noChange
            return lastDecision
        }
        startNext(now: now)
        lastDecision = .finished
        return lastDecision
    }

    @discardableResult
    public mutating func tick(now: Date) -> ActionDecision {
        guard let expiry = active.expiresAt, expiry <= now else {
            lastDecision = .noChange
            return lastDecision
        }
        startNext(now: now)
        lastDecision = .finished
        return lastDecision
    }

    public var queuedCount: Int { queue.count }

    private mutating func startNext(now: Date) {
        guard !queue.isEmpty else {
            active = ActiveBehavior(animation: "idle", priority: .idle)
            return
        }
        let best = queue.indices.max {
            let lhs = queue[$0]
            let rhs = queue[$1]
            if lhs.action.priority == rhs.action.priority { return lhs.sequence > rhs.sequence }
            return lhs.action.priority < rhs.action.priority
        }!
        active = activated(queue.remove(at: best).action, now: now)
    }

    private func activated(_ action: ActiveBehavior, now: Date) -> ActiveBehavior {
        var result = action
        if let duration = result.duration {
            result.expiresAt = now.addingTimeInterval(duration)
        }
        return result
    }
}
