import Foundation
import XCTest
@testable import CatAtWorkCore

final class BehaviorAndPhysicsTests: XCTestCase {
    func testDirectInteractionOutranksSystemEvent() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 100)
        _ = engine.handle(.petting, now: now)
        _ = engine.handle(.workspaceCategory(.work), now: now)
        XCTAssertEqual(engine.active.animation, "petting")
    }

    func testGrabbedStateCannotBePreempted() {
        var engine = BehaviorEngine()
        _ = engine.handle(.grabbed)
        _ = engine.handle(.clicked)
        _ = engine.handle(.wake)
        XCTAssertEqual(engine.active.animation, "pickup")
    }

    func testThrowVelocityIsClampedAndPetLands() {
        var physics = PetPhysics(position: .init(x: 50, y: 10), velocity: .init(x: 100_000, y: -500))
        let landed = physics.step(deltaTime: 1, floorY: 0, horizontalBounds: 0...100)
        XCTAssertLessThanOrEqual(abs(physics.velocity.x), physics.maxSpeed)
        XCTAssertLessThanOrEqual(physics.position.x, 100)
        XCTAssertTrue(landed || physics.position.y > 0)
    }

    func testRestingOnFloorDoesNotRepeatedlyLand() {
        var physics = PetPhysics(position: .init(x: 50, y: 20), velocity: .init())

        for _ in 0..<120 {
            XCTAssertFalse(
                physics.step(deltaTime: 0.05, floorY: 20, horizontalBounds: 0...100),
                "A supported pet must not emit a new landing event on each watchdog tick"
            )
            XCTAssertEqual(physics.position.y, 20, accuracy: 0.0001)
            XCTAssertEqual(physics.velocity.y, 0, accuracy: 0.0001)
        }
    }

    func testAirbornePetEmitsExactlyOneLandingEvent() {
        var physics = PetPhysics(position: .init(x: 50, y: 25), velocity: .init(x: 0, y: -500))
        var landingCount = 0

        for _ in 0..<20 {
            if physics.step(deltaTime: 0.05, floorY: 20, horizontalBounds: 0...100) {
                landingCount += 1
            }
        }

        XCTAssertEqual(landingCount, 1)
    }

    func testReleasePolicyDoesNotLandBeforePhysicalImpact() {
        XCTAssertEqual(PetReleasePolicy.classify(speed: 50, heightAboveFloor: 4), .placed)
        XCTAssertEqual(PetReleasePolicy.classify(speed: 50, heightAboveFloor: 80), .dropped)
        XCTAssertEqual(PetReleasePolicy.classify(speed: 500, heightAboveFloor: 4), .thrown)
    }

    func testClassifiesWindowTitleWithoutPersistingIt() {
        let classifier = WorkspaceClassifier()
        XCTAssertEqual(classifier.classify(bundleIdentifier: "com.apple.Safari", windowTitle: "private account"), .browsing)
        XCTAssertEqual(classifier.classify(bundleIdentifier: "us.zoom.xos", windowTitle: "Team Meeting"), .meeting)
    }

    func testMeetingIsQuietAndLowBatteryWaits() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 200)
        _ = engine.handle(.workspaceCategory(.meeting), now: now)
        XCTAssertEqual(engine.active.animation, "idle")
        _ = engine.handle(.batteryLevelChanged(0.10), now: now.addingTimeInterval(5))
        XCTAssertEqual(engine.active.animation, "waiting")
    }

    func testPointerProximityDoesNotWakeSleepingCatButClickDoes() {
        var engine = BehaviorEngine()
        _ = engine.handle(.sleep)
        _ = engine.handle(.pointerApproached)
        XCTAssertEqual(engine.active.animation, "sleep")
        _ = engine.handle(.clicked)
        XCTAssertEqual(engine.active.animation, "wakeUp")
    }

    func testSleepSkipsSettleDownIntroAfterFirstCycle() {
        let frame = PetFrame(
            image: "frame.png",
            sourceSize: .init(width: 10, height: 10),
            trimRect: .init(x: 0, y: 0, width: 10, height: 10),
            pivot: .init(x: 0.5, y: 1),
            duration: 0.01
        )
        let sleep = PetAnimation(id: "sleep", loopMode: .loop, frames: Array(repeating: frame, count: 24))
        var player = AnimationPlayer(animationID: "sleep")
        for _ in 0..<24 { _ = player.advance(deltaTime: 0.01, animation: sleep) }
        XCTAssertEqual(player.frameIndex, 8)
    }

    func testActivityContextDoesNotSeizeBodyAnimation() {
        var engine = BehaviorEngine()
        _ = engine.handle(.autonomousMicro("idleEar"))
        _ = engine.handle(.userBecameActive)
        XCTAssertEqual(engine.active.animation, "idleEar")
        _ = engine.handle(.userBecameIdle)
        XCTAssertEqual(engine.active.animation, "idleEar")
    }

    func testNormalActionsQueueWithoutResettingCurrentAction() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 400)
        _ = engine.handle(.autonomousMicro("idleEar"), now: now)
        _ = engine.handle(.clicked, now: now.addingTimeInterval(0.1))
        _ = engine.handle(.clicked, now: now.addingTimeInterval(0.2))

        XCTAssertEqual(engine.active.animation, "idleEar")
        XCTAssertEqual(engine.queuedActionCount, 1)
        _ = engine.handle(.animationFinished("idleEar"), now: now.addingTimeInterval(2))
        XCTAssertEqual(engine.active.animation, "wave")
    }

    func testLocomotionUsesAuthoredPoseBridgesInBothDirections() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 450)

        _ = engine.handle(.autonomousWalkRight, now: now)
        XCTAssertEqual(engine.active.animation, "sitToStand")
        XCTAssertEqual(engine.queuedActionCount, 1)

        _ = engine.handle(.animationFinished("sitToStand"), now: now.addingTimeInterval(2.6))
        XCTAssertEqual(engine.active.animation, "walkRight")
        XCTAssertEqual(engine.pose, .standing)

        _ = engine.handle(.tick(now.addingTimeInterval(3.5)), now: now.addingTimeInterval(3.5))
        XCTAssertEqual(engine.active.animation, "standToSit")

        _ = engine.handle(.animationFinished("standToSit"), now: now.addingTimeInterval(6.1))
        XCTAssertEqual(engine.active.animation, "idle")
        XCTAssertEqual(engine.pose, .seated)
    }

    func testQueuedDurationStartsWhenQueuedActionActuallyBegins() {
        var coordinator = ActionCoordinator()
        let now = Date(timeIntervalSince1970: 500)
        _ = coordinator.submit(ActiveBehavior(animation: "sitToStand", priority: .autonomous), now: now)
        _ = coordinator.submit(
            ActiveBehavior(animation: "walkRight", priority: .autonomous,
                           expiresAt: now.addingTimeInterval(0.8), duration: 0.8),
            now: now
        )

        _ = coordinator.finish("sitToStand", now: now.addingTimeInterval(3))
        XCTAssertEqual(coordinator.active.animation, "walkRight")
        XCTAssertEqual(coordinator.active.expiresAt, now.addingTimeInterval(3.8))
    }

    func testQueuedIntentReroutesFromActualPoseAndSelectedPlanIsAtomic() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 525)

        _ = engine.handle(.autonomousWalkRight, now: now)
        XCTAssertEqual(engine.active.animation, "sitToStand")

        // A later, higher-priority wave cannot split the already-selected
        // sitToStand -> walkRight plan.
        _ = engine.handle(.clicked, now: now.addingTimeInterval(0.1))
        XCTAssertEqual(engine.queuedActionCount, 2)
        _ = engine.handle(.animationFinished("sitToStand"), now: now.addingTimeInterval(0.2))
        XCTAssertEqual(engine.active.animation, "walkRight")
        XCTAssertEqual(engine.pose, .standing)

        // This lower-priority walk is intentionally queued while standing. The
        // wave wins next and changes the actual pose to seated before it starts.
        _ = engine.handle(.autonomousWalkLeft, now: now.addingTimeInterval(0.3))
        _ = engine.handle(.tick(now.addingTimeInterval(1.1)), now: now.addingTimeInterval(1.1))
        XCTAssertEqual(engine.active.animation, "standToSit")

        _ = engine.handle(.animationFinished("standToSit"), now: now.addingTimeInterval(1.2))
        XCTAssertEqual(engine.active.animation, "wave")
        XCTAssertEqual(engine.pose, .seated)

        _ = engine.handle(.animationFinished("wave"), now: now.addingTimeInterval(1.3))
        XCTAssertEqual(engine.active.animation, "sitToStand")
        XCTAssertEqual(engine.pose, .seated)

        _ = engine.handle(.animationFinished("sitToStand"), now: now.addingTimeInterval(1.4))
        XCTAssertEqual(engine.active.animation, "walkLeft")
        XCTAssertEqual(engine.pose, .standing)
    }

    func testForcedActionClearsAnAtomicContinuationEvenWhenAnimationMatches() {
        var coordinator = ActionCoordinator()
        let bridge = ActiveBehavior(animation: "bridge", priority: .autonomous)
        let target = ActiveBehavior(animation: "target", priority: .autonomous)

        _ = coordinator.submit(target, planner: { [bridge, $0] })
        XCTAssertEqual(coordinator.active.animation, "bridge")
        XCTAssertEqual(coordinator.queuedCount, 1)

        XCTAssertEqual(coordinator.submit(bridge, force: true), .forced)
        XCTAssertEqual(coordinator.queuedCount, 0)
        _ = coordinator.finish("bridge")
        XCTAssertEqual(coordinator.active.animation, "idle")
    }

    func testSixtySecondsWithoutInputSchedulesMicroMotionRoamingAndSleep() {
        var scheduler = AutonomyScheduler(startTime: 0, seed: 42)
        var cues: [AutonomyCue] = []
        for tick in 0...1_800 {
            if let cue = scheduler.nextCue(at: Double(tick) / 30, isAvailable: true) {
                cues.append(cue)
            }
        }

        XCTAssertTrue(cues.contains(.micro("idleEar")))
        XCTAssertTrue(cues.contains(.micro("idleTail")))
        XCTAssertTrue(cues.contains { if case .roam = $0 { true } else { false } })
        XCTAssertTrue(cues.contains { if case .major("sleep") = $0 { true } else { false } })
        XCTAssertTrue(cues.contains { if case .major = $0 { true } else { false } })
    }

    func testSixtySecondsWithSerializedBusyWindowsStillProducesCompleteAutonomyTrace() {
        var scheduler = AutonomyScheduler(startTime: 0, seed: 42)
        var cues: [AutonomyCue] = []
        var busyUntil = 0.0
        for tick in 0...1_800 {
            let time = Double(tick) / 30
            guard let cue = scheduler.nextCue(
                at: time,
                isAvailable: time >= busyUntil,
                context: .init(userIsActive: false, hour: 14)
            ) else { continue }
            cues.append(cue)
            switch cue {
            case .micro: busyUntil = time + 2
            case .roam: busyUntil = time + 6
            case .major(let animation): busyUntil = time + (animation == "sleep" ? 45 : 4.5)
            }
        }

        XCTAssertTrue(cues.contains(.micro("idleEar")))
        XCTAssertTrue(cues.contains(.micro("idleTail")))
        XCTAssertTrue(cues.contains { if case .roam = $0 { true } else { false } })
        XCTAssertTrue(cues.contains { if case .major("sleep") = $0 { true } else { false } })
    }

    func testAutonomyChoicesRespondToWorkMeetingMusicAndIdleContext() {
        func majorActions(context: AutonomyContext, seeds: ClosedRange<UInt64>) -> [String] {
            seeds.compactMap { seed in
                var scheduler = AutonomyScheduler(startTime: 0, seed: seed)
                for tick in 0...1_800 {
                    if case .major(let animation) = scheduler.nextCue(
                        at: Double(tick) / 30,
                        isAvailable: true,
                        context: context
                    ) {
                        return animation
                    }
                }
                return nil
            }
        }

        let work = majorActions(
            context: .init(userIsActive: true, workspace: .work, hour: 14),
            seeds: 1...24
        )
        XCTAssertTrue(work.contains("working"))
        XCTAssertFalse(work.contains("bellyRoll"))

        let meeting = majorActions(
            context: .init(userIsActive: true, workspace: .meeting, hour: 14),
            seeds: 1...24
        )
        XCTAssertTrue(Set(meeting).isSubset(of: ["working", "groom", "waiting", "sleep"]))

        let music = majorActions(
            context: .init(userIsActive: true, mediaIsPlaying: true, outputVolume: 0.8, hour: 14),
            seeds: 1...24
        )
        XCTAssertTrue(music.contains("happy"))

        let mutedMusic = majorActions(
            context: .init(userIsActive: true, mediaIsPlaying: true, outputVolume: 0, hour: 14),
            seeds: 1...24
        )
        XCTAssertFalse(mutedMusic.contains("happy"))

        let idle = majorActions(
            context: .init(userIsActive: false, hour: 14),
            seeds: 1...24
        )
        XCTAssertTrue(idle.contains("waiting"))
        XCTAssertFalse(idle.contains("jump"))
    }

    func testGrabAndLandingAreTheOnlyForcedPhysicalTransitions() {
        var engine = BehaviorEngine()
        _ = engine.handle(.clicked)
        _ = engine.handle(.grabbed)
        XCTAssertEqual(engine.active.animation, "pickup")
        XCTAssertEqual(engine.lastDecision, .forced)
        _ = engine.handle(.thrown(velocity: .init(x: 100, y: 100)))
        XCTAssertEqual(engine.active.animation, "thrown")
        _ = engine.handle(.landed)
        XCTAssertEqual(engine.active.animation, "landing")
    }

    func testLandingReleasesGrabOwnershipAndCompletesNormally() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 550)
        _ = engine.handle(.grabbed, now: now)
        _ = engine.handle(.landed, now: now.addingTimeInterval(1))
        _ = engine.handle(.animationFinished("landing"), now: now.addingTimeInterval(3))

        XCTAssertEqual(engine.active.animation, "idle")
        _ = engine.handle(.clicked, now: now.addingTimeInterval(3.1))
        XCTAssertEqual(engine.active.animation, "wave")
    }

    func testPointerIntentDuringLandingDoesNotPlayAfterRecovery() {
        var engine = BehaviorEngine()
        let now = Date(timeIntervalSince1970: 600)
        _ = engine.handle(.landed, now: now)
        _ = engine.handle(.pointerApproached, now: now.addingTimeInterval(0.2))

        XCTAssertEqual(engine.active.animation, "landing")
        XCTAssertEqual(engine.lastDecision, .ignoredWhilePhysical)
        XCTAssertEqual(engine.queuedActionCount, 0)

        _ = engine.handle(.animationFinished("landing"), now: now.addingTimeInterval(2.5))
        XCTAssertEqual(engine.active.animation, "idle")
    }

    func testPassiveGazeNeverUsesHardSideOrTailFlipDirections() {
        let points: [(Double, Double)] = [
            (500, 0), (500, 500), (0, 500), (-500, 500),
            (-500, 0), (-500, -500), (0, -500), (500, -500),
        ]
        for point in points {
            let index = LookDirectionPolicy.passiveTargetIndex(
                pointerX: point.0,
                pointerY: point.1,
                centerX: 0,
                centerY: 0
            )
            XCTAssertTrue([0, 1, 2, 14, 15].contains(index), "Unexpected gaze index: \(index)")
        }
    }

    func testPassiveGazeMatchesPointerSideAndKeepsCenteredPointerNeutral() {
        XCTAssertEqual(
            LookDirectionPolicy.passiveTargetIndex(pointerX: 400, pointerY: 0, centerX: 0, centerY: 0),
            2
        )
        XCTAssertEqual(
            LookDirectionPolicy.passiveTargetIndex(pointerX: -400, pointerY: 0, centerX: 0, centerY: 0),
            14
        )
        XCTAssertEqual(
            LookDirectionPolicy.passiveTargetIndex(pointerX: 0, pointerY: -400, centerX: 0, centerY: 0),
            0
        )
    }

    func testPointerPassHoverAndPetAreDistinctIntents() {
        var recognizer = PointerIntentRecognizer()
        XCTAssertNil(recognizer.ingest(point: .init(x: 10, y: 10), at: 0, region: .back, pointerOnLeft: true))
        XCTAssertNil(recognizer.ingest(point: .init(x: 14, y: 10), at: 0.20, region: .back, pointerOnLeft: true))
        XCTAssertEqual(
            recognizer.ingest(point: .init(x: 18, y: 10), at: 0.31, region: .back, pointerOnLeft: true),
            .hover(.back, pointerOnLeft: true)
        )
        XCTAssertNil(recognizer.ingest(point: .init(x: 80, y: 10), at: 0.50, region: .back, pointerOnLeft: true))
        XCTAssertNil(recognizer.ingest(point: .init(x: 30, y: 10), at: 0.70, region: .back, pointerOnLeft: true))
        XCTAssertEqual(
            recognizer.ingest(point: .init(x: 85, y: 10), at: 0.90, region: .back, pointerOnLeft: true),
            .pet(.back, pointerOnLeft: true)
        )
    }

    func testFastReversalsProduceOneShooIntentBeforePetting() {
        var recognizer = PointerIntentRecognizer()
        _ = recognizer.ingest(point: .init(x: 0, y: 0), at: 0, region: .back, pointerOnLeft: true)
        _ = recognizer.ingest(point: .init(x: 120, y: 0), at: 0.05, region: .back, pointerOnLeft: false)
        _ = recognizer.ingest(point: .init(x: 0, y: 0), at: 0.10, region: .back, pointerOnLeft: true)
        XCTAssertEqual(
            recognizer.ingest(point: .init(x: 120, y: 0), at: 0.15, region: .back, pointerOnLeft: false),
            .shoo(moveRight: true)
        )
    }
}
