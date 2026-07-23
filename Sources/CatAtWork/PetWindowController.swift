import AppKit
import CatAtWorkCore
import QuartzCore

@MainActor
final class PetWindowController: NSWindowController {
    private let petView: MetalPetView
    private var displayLink: CADisplayLink?
    private var animationWatchdog: Timer?
    private var eventMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var behavior = BehaviorEngine()
    private var physics = PetPhysics()
    private var player = AnimationPlayer()
    private var manifest: PetManifest?
    private var packageRoot: URL?
    private var packageContract = PetPackageContract.standard
    private var sessionGeneration: UInt64 = 0
    private var lastTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var lastPhysicsTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var dragSamples: [(time: CFTimeInterval, point: NSPoint)] = []
    private var mouseDownPoint: NSPoint?
    private var isDragging = false
    private var currentFrame: PetFrame?
    private var lastPettingPoint: NSPoint?
    private var accumulatedPettingDistance: CGFloat = 0
    private var lookDirectionIndex = 0
    private var targetLookDirectionIndex = 0
    private var displayLinkIsThrottled = false
    private var canvasLayout = PetCanvasLayout(frames: [])
    private var pointerChaseIsActive = false
    private var pointerDesiredVelocity: Double = 0
    private var mouseInterestUntil: CFTimeInterval = 0
    private var nextMouseInterestAt = CACurrentMediaTime() + Double.random(in: 25...55)
    private var gazeUntil: CFTimeInterval = 0
    private var gazeTrackingUntil: CFTimeInterval = 0
    private var nextGazeAt = CACurrentMediaTime() + Double.random(in: 8...25)
    private var shooCooldownUntil: CFTimeInterval = 0
    private var shooRunUntil: CFTimeInterval = 0
    private var lastPointerSample: (time: CFTimeInterval, point: NSPoint)?
    private var roamUntil: CFTimeInterval = 0
    private var roamDirection: Double = Bool.random() ? 1 : -1
    private var roamTargetX: Double?
    private var roamIsRunning = false
    private var interactionFacesLeft = false
    private var interactionDirectionUntil: CFTimeInterval = 0
    private var lastLookStepAt: CFTimeInterval = 0
    private var pendingLookDirectionIndex = 0
    private var pendingLookDirectionSince: CFTimeInterval = 0
    private var smoothedPointerSpeed: CGFloat = 0
    private var lastFastNearPointerAt: CFTimeInterval = 0
    private var lastFastHorizontalDirection: CGFloat = 0
    private var fastNearReversalCount = 0
    private var autonomyScheduler = AutonomyScheduler(
        startTime: CACurrentMediaTime(),
        seed: UInt64.random(in: UInt64.min...UInt64.max)
    )
    private var autonomyContext = AutonomyContext(
        hour: Calendar.current.component(.hour, from: .now)
    )
    private var pendingActivityEvent: PetEvent?
    private var pointerIntentRecognizer = PointerIntentRecognizer()
    private let diagnostics = PetDiagnostics.shared
    private var isContextMenuOpen = false
    private var lastPointerDiagnosticAt: CFTimeInterval = 0

    init() {
        petView = MetalPetView(frame: NSRect(x: 0, y: 0, width: 320, height: 320))
        let panel = NSPanel(
            contentRect: petView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.isOpaque = false
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.contentView = petView
        petView.layer?.isOpaque = false
        petView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.acceptsMouseMovedEvents = true
        super.init(window: panel)
        petView.onRightMouseDown = { [weak self] event in self?.showContextMenu(for: event) }
        installMouseHandling()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.keepPetVisible() }
        }
        startDisplayLink()
        startAnimationWatchdog()
        placeOnVisibleScreen()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func loadPet(at root: URL) throws {
        let imported = try PetPackageImporter().inspectDirectory(at: root)
        let previousAnchor = manifest == nil ? nil : windowWorldAnchor()
        let nextContract = PetPackageContract(manifest: imported.manifest)
        let frames = imported.manifest.animations.flatMap(\.frames) + imported.manifest.lookDirections.map(\.frame)

        manifest = imported.manifest
        packageRoot = root
        packageContract = nextContract
        canvasLayout = PetCanvasLayout(frames: frames, margin: 16)
        resizeWindowForCanvas(preserving: previousAnchor)
        if previousAnchor == nil { placeOnVisibleScreen() }
        resetSessionState(now: CACurrentMediaTime())
        UserDefaults.standard.set(packageContract.supportsPhysicalInteraction, forKey: "currentPetSupportsThrow")
        UserDefaults.standard.set(packageContract.supportsPointerLocomotion, forKey: "currentPetSupportsLocomotion")
        updateRenderedFrame()
    }

    func showPet() {
        showWindow(nil)
        window?.orderFrontRegardless()
    }

    func handleSystemEvent(_ event: PetEvent) {
        updateAutonomyContext(for: event)
        var contextFields = autonomyDiagnosticFields
        contextFields.merge(event.diagnosticFields) { _, new in new }
        diagnostics.log(category: "context", event: event.diagnosticName, fields: contextFields)
        let shouldInterruptMotion: Bool
        switch event {
        case .networkChanged(false), .lockChanged, .wake, .sleep:
            shouldInterruptMotion = true
        case .batteryLevelChanged(let level) where level <= 0.15:
            shouldInterruptMotion = true
        default: shouldInterruptMotion = false
        }
        if !shouldInterruptMotion, abs(physics.velocity.x) >= 8 {
            pendingActivityEvent = event
            return
        }
        if shouldInterruptMotion, behavior.active.priority < .grabbedOrThrown {
            roamUntil = 0
            roamTargetX = nil
            pointerChaseIsActive = false
            physics.velocity.x = 0
            // Do not let a roam window expire invisibly while a short system
            // reaction owns the state machine. Resume autonomy soon afterwards.
        }
        dispatch(event, source: "system")
        if event == .wake { keepPetVisible() }
    }

    private func placeOnVisibleScreen() {
        guard let screen = NSScreen.main, let window else { return }
        let area = screen.visibleFrame
        let origin = NSPoint(
            x: area.maxX - window.frame.width - 40,
            y: floorWindowOriginY(in: area)
        )
        window.setFrameOrigin(origin)
        physics.position = .init(x: origin.x, y: origin.y)
    }

    private func keepPetVisible() {
        guard let window else { return }
        let target = NSScreen.screens.first(where: { $0.frame.intersects(window.frame) }) ?? NSScreen.main
        guard let area = target?.visibleFrame else { return }
        let x = min(max(window.frame.minX, area.minX), max(area.minX, area.maxX - window.frame.width))
        let floorY = floorWindowOriginY(in: area)
        let y = min(max(window.frame.minY, floorY), max(floorY, area.maxY - window.frame.height))
        window.setFrameOrigin(NSPoint(x: x, y: y))
        physics.position = .init(x: x, y: y)
    }

    private func updateAutonomyContext(for event: PetEvent) {
        switch event {
        case .userBecameActive: autonomyContext.userIsActive = true
        case .userBecameIdle: autonomyContext.userIsActive = false
        case .workspaceCategory(let category): autonomyContext.workspace = category
        case .mediaPlaybackChanged(let playing): autonomyContext.mediaIsPlaying = playing
        case .chargingChanged(let charging): autonomyContext.isCharging = charging
        case .volumeChanged(let volume): autonomyContext.outputVolume = volume
        case .timePeriodChanged(let hour): autonomyContext.hour = hour
        default: break
        }
    }

    private func currentCanvasScaleY() -> Double {
        guard let window, canvasLayout.size.height > 0 else { return runtimeCanvasScale() }
        return window.frame.height / Double(canvasLayout.size.height)
    }

    private func runtimeCanvasScale() -> Double {
        packageContract.canvasScale(userScale: UserDefaults.standard.double(forKey: "petScale"))
    }

    private func floorWindowOriginY(in area: NSRect) -> Double {
        canvasLayout.windowOriginY(
            placingAnchorAt: area.minY + 20,
            scale: currentCanvasScaleY()
        )
    }

    private func windowWorldAnchor() -> NSPoint? {
        guard let window, canvasLayout.size.width > 0, canvasLayout.size.height > 0 else { return nil }
        let scaleX = window.frame.width / Double(canvasLayout.size.width)
        let scaleY = window.frame.height / Double(canvasLayout.size.height)
        return NSPoint(
            x: window.frame.minX + canvasLayout.anchorFromTop.x * scaleX,
            y: canvasLayout.anchorWorldY(forWindowOriginY: window.frame.minY, scale: scaleY)
        )
    }

    private func resizeWindowForCanvas(preserving worldAnchor: NSPoint?) {
        guard let window else { return }
        let scale = runtimeCanvasScale()
        let size = NSSize(
            width: Double(canvasLayout.size.width) * scale,
            height: Double(canvasLayout.size.height) * scale
        )
        window.setContentSize(size)
        if let worldAnchor {
            window.setFrameOrigin(NSPoint(
                x: worldAnchor.x - canvasLayout.anchorFromTop.x * scale,
                y: canvasLayout.windowOriginY(placingAnchorAt: worldAnchor.y, scale: scale)
            ))
            physics.position = .init(x: window.frame.minX, y: window.frame.minY)
        }
    }

    private func installMouseHandling() {
        let down = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.beginDrag(event)
            return event
        }
        let dragged = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.continueDrag(event)
            return event
        }
        let up = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.endDrag(event)
            return event
        }
        let moved = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.observePointer() }
        }
        // Local movement keeps hover gaze and no-button petting available over
        // the cat even when Input Monitoring is denied. The 30 Hz passthrough
        // check first makes the transparent panel hittable under the pointer.
        let localMoved = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            if event.window === self?.window { self?.observePointer() }
            return event
        }
        eventMonitors = [down, dragged, up, moved, localMoved].compactMap { $0 }
    }

    private func beginDrag(_ event: NSEvent) {
        guard event.window === window else { return }
        if event.clickCount >= 2 {
            showSettings()
            mouseDownPoint = nil
            return
        }
        guard UserDefaults.standard.bool(forKey: "throwEnabled"),
              packageContract.supportsPhysicalInteraction else {
            dispatch(.clicked, source: "click")
            return
        }
        mouseDownPoint = NSEvent.mouseLocation
        dragSamples = [(CACurrentMediaTime(), NSEvent.mouseLocation)]
    }

    private func observePointer() {
        guard !isDragging, !isContextMenuOpen, let window else { return }
        let point = NSEvent.mouseLocation
        let now = CACurrentMediaTime()
        let pointerSpeed: CGFloat
        let horizontalDelta: CGFloat
        if let last = lastPointerSample, now > last.time {
            horizontalDelta = point.x - last.point.x
            let instantaneous = hypot(horizontalDelta, point.y - last.point.y) / (now - last.time)
            smoothedPointerSpeed = smoothedPointerSpeed * 0.72 + instantaneous * 0.28
            pointerSpeed = smoothedPointerSpeed
        } else {
            horizontalDelta = 0
            pointerSpeed = 0
        }
        lastPointerSample = (now, point)
        let hitFrame = interactiveFrame(in: window)
        window.ignoresMouseEvents = !hitFrame.contains(point)

        let bodyRegion = pointerRegion(at: point, in: hitFrame)
        let pointerOnLeft = point.x < hitFrame.midX
        let intent = pointerIntentRecognizer.ingest(
            point: point, at: now, region: bodyRegion, pointerOnLeft: pointerOnLeft
        )
        var recognizedBodyGesture = false
        if hitFrame.contains(point) {
            // Passing over the cat immediately affects only the gaze layer.
            gazeTrackingUntil = max(gazeTrackingUntil, now + 0.9)
            gazeUntil = max(gazeUntil, gazeTrackingUntil + 1.2)
            updateLookTarget(pointer: point, center: NSPoint(x: window.frame.midX, y: window.frame.midY))
        }
        switch intent {
        case .shoo(let moveRight):
            recognizedBodyGesture = true
            mouseInterestUntil = 0
            gazeUntil = 0
            shooCooldownUntil = now + Double.random(in: 25...45)
            shooRunUntil = now + 1.25
            nextMouseInterestAt = shooCooldownUntil + Double.random(in: 20...50)
            dispatch(moveRight ? .shooRight : .shooLeft, source: "pointer-shoo")
            if behavior.lastDecision == .ignoredUnavailable {
                shooRunUntil = 0
            } else {
                physics.velocity.x = moveRight ? 280 : -280
            }
        case .pet(let region, let lockedLeft):
            recognizedBodyGesture = true
            mouseInterestUntil = 0
            pointerChaseIsActive = false
            interactionFacesLeft = lockedLeft
            interactionDirectionUntil = now + 3.4
            dispatch(pettingEvent(for: region, pointerOnLeft: lockedLeft), source: "pointer-pet-\(region.rawValue)")
        case .hover(let region, _):
            dispatch(.pointerApproached, source: "pointer-hover-\(region.rawValue)")
        case nil:
            break
        }

        if !recognizedBodyGesture,
           UserDefaults.standard.bool(forKey: "chasePointer"),
                  mouseInterestUntil > now,
                  window.screen?.frame.contains(point) == true {
            let horizontalDistance = abs(point.x - window.frame.midX)
            if pointerChaseIsActive ? horizontalDistance > 125 : horizontalDistance > 170 {
                let movingRight = point.x > window.frame.midX
                let running = horizontalDistance > 320
                let desiredVelocity = min(running ? 300 : 135, max(running ? 190 : 80, horizontalDistance * 0.75)) * (movingRight ? 1.0 : -1.0)
                let requestedID = running
                    ? (movingRight ? "runRight" : "runLeft")
                    : (movingRight ? "walkRight" : "walkLeft")
                if packageContract.resolvedAnimationID(for: requestedID) != nil {
                    pointerChaseIsActive = true
                    pointerDesiredVelocity = desiredVelocity
                    if running {
                        dispatch(movingRight ? .pointerChaseRight : .pointerChaseLeft, source: "cat-visits-pointer")
                    } else {
                        dispatch(movingRight ? .pointerWalkRight : .pointerWalkLeft, source: "cat-visits-pointer")
                    }
                    if ["walkLeft", "walkRight", "runLeft", "runRight"].contains(behavior.active.animation) {
                        physics.velocity.x += (desiredVelocity - physics.velocity.x) * 0.22
                    } else {
                        physics.velocity.x *= 0.72
                    }
                } else {
                    pointerChaseIsActive = false
                    pointerDesiredVelocity = 0
                    physics.velocity.x *= 0.72
                }
            } else {
                pointerChaseIsActive = false
                pointerDesiredVelocity = 0
                physics.velocity.x *= 0.72
                gazeTrackingUntil = max(gazeTrackingUntil, now + 0.9)
                gazeUntil = max(gazeUntil, gazeTrackingUntil + 1.6)
                updateLookTarget(pointer: point, center: NSPoint(x: window.frame.midX, y: window.frame.midY))
            }
        } else if gazeTrackingUntil > now, window.screen?.frame.contains(point) == true {
            updateLookTarget(pointer: point, center: NSPoint(x: window.frame.midX, y: window.frame.midY))
        }
        if now - lastPointerDiagnosticAt >= 0.25 {
            lastPointerDiagnosticAt = now
            diagnostics.log(category: "input", event: "pointer-sample", fields: [
                "region": bodyRegion.rawValue,
                "speedBand": pointerSpeed < 200 ? "slow" : pointerSpeed < 900 ? "medium" : "fast",
                "inside": String(hitFrame.contains(point)),
            ])
        }
    }

    private func continueDrag(_ event: NSEvent) {
        guard let mouseDownPoint, let window else { return }
        let point = NSEvent.mouseLocation
        if !isDragging, hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) >= 12 {
            isDragging = true
            dispatch(.grabbed, source: "drag-began")
        }
        guard isDragging else { return }
        // 把窗口顶部的“后颈抓取点”固定在指针下方，让 pickup 的逐帧伸长向下展开，
        // 而不是整只猫围绕窗口中心上下跳动。
        window.setFrameOrigin(NSPoint(
            x: point.x - window.frame.width / 2,
            y: point.y - window.frame.height + 22
        ))
        dragSamples.append((CACurrentMediaTime(), point))
        dragSamples = Array(dragSamples.suffix(6))
    }

    private func endDrag(_ event: NSEvent) {
        guard mouseDownPoint != nil else { return }
        defer { mouseDownPoint = nil }
        guard isDragging else {
            dispatch(.clicked, source: "click")
            return
        }
        isDragging = false
        let velocity: Vector2D
        if let first = dragSamples.first, let last = dragSamples.last, last.time > first.time {
            let dt = last.time - first.time
            velocity = .init(x: (last.point.x - first.point.x) / dt, y: (last.point.y - first.point.y) / dt)
        } else {
            velocity = .init()
        }
        if let origin = window?.frame.origin { physics.position = .init(x: origin.x, y: origin.y) }
        let releaseSpeed = hypot(velocity.x, velocity.y)
        let area = (window?.screen ?? NSScreen.main)?.visibleFrame
        let floorY = area.map { floorWindowOriginY(in: $0) } ?? physics.position.y
        switch PetReleasePolicy.classify(
            speed: releaseSpeed,
            heightAboveFloor: max(0, physics.position.y - floorY)
        ) {
        case .placed:
            physics.velocity = .init(x: velocity.x * 0.2, y: min(0, velocity.y * 0.2))
            physics.position.y = floorY
            physics.velocity.y = 0
            dispatch(.landed, source: "drag-placed-on-floor")
        case .dropped:
            physics.velocity = .init(x: velocity.x * 0.2, y: min(0, velocity.y * 0.2))
            // A gentle drop is still airborne. Playing landing here used to
            // restart landing when the real impact arrived.
            dispatch(.thrown(velocity: physics.velocity), source: "drag-dropped")
        case .thrown:
            physics.velocity = velocity
            dispatch(.thrown(velocity: velocity), source: "drag-thrown")
        }
    }

    private func startDisplayLink() {
        let link = petView.displayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func startAnimationWatchdog() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.behaviorTick(timestamp: CACurrentMediaTime())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationWatchdog = timer
    }

    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        // Spatial integration follows the actual display cadence (60/120 Hz),
        // while the independent watchdog owns 30 Hz behavior and animation.
        // This prevents the transparent window from moving in visible 30 Hz
        // steps on a ProMotion display.
        stepPhysicsAndWindow(timestamp: CACurrentMediaTime())
        updateRenderedFrame()
    }

    private func behaviorTick(timestamp: CFTimeInterval) {
        let dt = min(max(timestamp - lastTimestamp, 0), 1.0 / 20.0)
        lastTimestamp = timestamp
        updateMousePassthrough()
        dispatch(.tick(.now), source: "behavior-clock")
        updateAmbientBehavior(timestamp: timestamp)
        synchronizeLocomotion(timestamp: timestamp, deltaTime: dt)
        updateDisplayLinkRate()
        player.transition(to: behavior.active.animation)
        if let animation = manifest?.animation(named: player.animationID) {
            _ = player.advance(deltaTime: dt, animation: animation)
            if player.isFinished(animation: animation) {
                dispatch(.animationFinished(animation.id), source: "animation-finished")
                if behavior.active.animation == animation.id {
                    player.restart()
                }
            }
        }
        updateRenderedFrame()
    }

    private func stepPhysicsAndWindow(timestamp: CFTimeInterval) {
        let dt = min(max(timestamp - lastPhysicsTimestamp, 0), 1.0 / 20.0)
        lastPhysicsTimestamp = timestamp
        if !isDragging, let screen = window?.screen ?? NSScreen.main, let window {
            let area = screen.visibleFrame
            let floorY = floorWindowOriginY(in: area)
            if physics.step(deltaTime: dt, floorY: floorY, horizontalBounds: area.minX...(area.maxX - window.frame.width)) {
                dispatch(.landed, source: "physics-impact")
            }
            let rightEdge = area.maxX - window.frame.width
            if abs(physics.velocity.x) < 80 {
                if abs(physics.position.x - area.minX) < 12 {
                    physics.position.x = area.minX
                    physics.velocity.x = 0
                } else if abs(physics.position.x - rightEdge) < 12 {
                    physics.position.x = rightEdge
                    physics.velocity.x = 0
                }
            }
            window.setFrameOrigin(NSPoint(x: physics.position.x, y: physics.position.y))
        }
    }

    private func updateDisplayLinkRate() {
        let shouldThrottle = !isDragging && behavior.active.priority == .idle &&
            abs(physics.velocity.x) < 1 && abs(physics.velocity.y) < 1
        guard shouldThrottle != displayLinkIsThrottled else { return }
        displayLinkIsThrottled = shouldThrottle
        displayLink?.preferredFrameRateRange = shouldThrottle
            ? CAFrameRateRange(minimum: 2, maximum: 30, preferred: 12)
            : CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
    }

    private func updateAmbientBehavior(timestamp: CFTimeInterval) {
        guard !isDragging else { return }
        if timestamp >= nextGazeAt,
           timestamp >= shooCooldownUntil,
           behavior.active.priority == .idle,
           roamUntil <= timestamp,
           mouseInterestUntil <= timestamp {
            gazeTrackingUntil = timestamp + Double.random(in: 1.2...2.2)
            gazeUntil = gazeTrackingUntil + 1.6
            nextGazeAt = gazeUntil + Double.random(in: 18...45)
        }
        if timestamp >= gazeTrackingUntil, timestamp < gazeUntil {
            // Reserve the tail of every gaze window for a smooth return to the
            // neutral head direction before normal body animation resumes.
            targetLookDirectionIndex = 0
        }
        if timestamp >= nextMouseInterestAt,
           timestamp >= shooCooldownUntil,
           UserDefaults.standard.bool(forKey: "chasePointer") {
            mouseInterestUntil = timestamp + Double.random(in: 5...9)
            nextMouseInterestAt = mouseInterestUntil + Double.random(in: 45...110)
        }
        let autonomyAvailable = behavior.active.priority == .idle &&
            roamUntil <= timestamp && mouseInterestUntil <= timestamp
        if let cue = autonomyScheduler.nextCue(
            at: timestamp,
            isAvailable: autonomyAvailable,
            context: autonomyContext
        ) {
            switch cue {
            case .micro(let animation):
                dispatch(.autonomousMicro(animation), source: "autonomy-scheduler")
            case .major(let animation):
                dispatch(.autonomousAction(animation), source: "autonomy-scheduler")
            case .roam(let run, let moveRight):
                scheduleRoam(timestamp: timestamp, run: run, moveRight: moveRight)
            }
        }
        if roamUntil > timestamp, mouseInterestUntil <= timestamp, behavior.active.priority <= .autonomous {
            if let target = roamTargetX, abs(target - physics.position.x) < 28 {
                roamUntil = timestamp
                roamTargetX = nil
            } else {
                if let target = roamTargetX { roamDirection = target > physics.position.x ? 1 : -1 }
                if roamIsRunning {
                    dispatch(roamDirection > 0 ? .autonomousRunRight : .autonomousRunLeft, source: "autonomous-roam")
                } else {
                    dispatch(roamDirection > 0 ? .autonomousWalkRight : .autonomousWalkLeft, source: "autonomous-roam")
                }
                // Pose bridges own the body before locomotion starts. Do not
                // slide the window while sitToStand is still on screen.
                if ["walkLeft", "walkRight", "runLeft", "runRight"].contains(behavior.active.animation) {
                    let desired = (roamIsRunning ? 210.0 : 82.0) * roamDirection
                    physics.velocity.x += (desired - physics.velocity.x) * 0.10
                } else {
                    physics.velocity.x *= 0.72
                }
            }
        }
    }

    private func scheduleRoam(timestamp: CFTimeInterval, run: Bool, moveRight: Bool) {
        let requestedID = run
            ? (moveRight ? "runRight" : "runLeft")
            : (moveRight ? "walkRight" : "walkLeft")
        guard packageContract.resolvedAnimationID(for: requestedID) != nil else { return }
        guard let window, let area = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let lower = area.minX
        let upper = max(lower, area.maxX - window.frame.width)
        let span = max(upper - lower, 1)
        var target = moveRight ? upper - span * 0.08 : lower + span * 0.08
        if abs(target - physics.position.x) < span * 0.28 {
            target = moveRight ? lower + span * 0.08 : upper - span * 0.08
        }
        roamTargetX = target
        roamDirection = target > physics.position.x ? 1 : -1
        roamIsRunning = run
        let speed = roamIsRunning ? 210.0 : 82.0
        roamUntil = timestamp + min(12, max(4, abs(target - physics.position.x) / speed + 1))
    }

    private func pointerRegion(at point: NSPoint, in frame: NSRect) -> PointerBodyRegion {
        guard frame.contains(point), frame.height > 0 else { return .outside }
        let vertical = (point.y - frame.minY) / frame.height
        if vertical >= 0.78 { return .ears }
        if vertical >= 0.58 { return .chin }
        if vertical <= 0.42 { return .belly }
        return .back
    }

    private func pettingEvent(for region: PointerBodyRegion, pointerOnLeft: Bool) -> PetEvent {
        switch region {
        case .ears: .earsPetted(pointerOnLeft: pointerOnLeft)
        case .chin: .chinPetted(pointerOnLeft: pointerOnLeft)
        case .belly: .bellyPetted(pointerOnLeft: pointerOnLeft)
        case .back: .backPetted(pointerOnLeft: pointerOnLeft)
        case .outside: .petting
        }
    }

    func previewAnimation(_ id: String) {
        guard manifest?.animations.contains(where: { $0.id == id }) == true else { return }
        physics.velocity.x = 0
        dispatch(.previewAnimation(id), source: "preview-menu")
    }

    var currentActionStatus: String {
        let count = manifest?.animation(named: player.animationID)?.frames.count ?? 0
        return "\(player.animationID) \(min(player.frameIndex + 1, max(count, 1)))/\(count)"
    }

    var currentPackageVersion: String { manifest?.assetVersion ?? "兼容包" }

    var availableAnimationIDs: [String] { manifest?.animations.map(\.id) ?? [] }

    var diagnosticsLogURL: URL? { diagnostics.logURL }

    private func dispatch(_ event: PetEvent, source: String) {
        let previous = behavior.active.animation
        let active = behavior.handle(event)
        let decision = behavior.lastDecision
        // A loop such as roam refreshes its expiry at 30 Hz. Logging those
        // maintenance samples hid the actual trigger chain and filled the 2 MB
        // file in under a minute. State changes and rejected physical-period
        // intents are sufficient to reproduce why an action happened.
        let shouldLogRequest: Bool
        switch decision {
        case .started, .queued, .forced, .finished, .ignoredWhilePhysical, .ignoredUnavailable:
            shouldLogRequest = true
        case .refreshed, .ignoredDuplicate, .noChange:
            shouldLogRequest = false
        }
        if shouldLogRequest {
            var fields: [String: String] = [
                "source": source,
                "decision": decision.rawValue,
                "previous": previous,
                "active": active.animation,
                "queued": String(behavior.queuedActionCount),
                "frame": String(player.frameIndex + 1),
                "petX": String(format: "%.0f", physics.position.x),
                "petY": String(format: "%.0f", physics.position.y),
                "velocityX": String(format: "%.0f", physics.velocity.x),
                "velocityY": String(format: "%.0f", physics.velocity.y),
            ]
            if let impact = physics.lastImpactVelocityY {
                fields["impactVelocityY"] = String(format: "%.0f", impact)
            }
            fields.merge(event.diagnosticFields) { _, new in new }
            if source == "autonomy-scheduler" {
                fields.merge(autonomyDiagnosticFields) { _, new in new }
            }
            diagnostics.log(category: "coordinator", event: event.diagnosticName, fields: fields)
        }
        if previous != active.animation {
            diagnostics.log(category: "action", event: "transition", fields: [
                "from": previous,
                "to": active.animation,
                "source": source,
            ])
        }
    }

    private var autonomyDiagnosticFields: [String: String] {
        let volumeBand = autonomyContext.outputVolume <= 0.05
            ? "muted"
            : autonomyContext.outputVolume >= 0.65 ? "loud" : "normal"
        return [
            "userActivity": autonomyContext.userIsActive ? "active" : "idle",
            "workspace": autonomyContext.workspace.rawValue,
            "media": autonomyContext.mediaIsPlaying ? "playing" : "stopped",
            "charging": String(autonomyContext.isCharging),
            "volumeBand": volumeBand,
            "timeBand": (autonomyContext.hour >= 22 || autonomyContext.hour < 7) ? "rest" : "day",
        ]
    }

    /// 位置移动和腿部动作必须来自同一个状态。之前行为过期后横向惯性仍然存在，
    /// 就会出现猫保持 idle/侧身僵直姿势却在桌面上滑行。
    private func synchronizeLocomotion(timestamp: CFTimeInterval, deltaTime: CFTimeInterval) {
        guard !isDragging, behavior.active.priority < .grabbedOrThrown else { return }

        let isShooing = shooRunUntil > timestamp
        let isVisitingPointer = mouseInterestUntil > timestamp && pointerChaseIsActive
        let isRoaming = roamUntil > timestamp && mouseInterestUntil <= timestamp
        let isActivelyMoving = isShooing || isVisitingPointer || isRoaming

        if isVisitingPointer,
           ["walkLeft", "walkRight", "runLeft", "runRight"].contains(behavior.active.animation),
           abs(pointerDesiredVelocity) >= 8 {
            physics.velocity.x += (pointerDesiredVelocity - physics.velocity.x) * 0.12
        }

        if !isActivelyMoving {
            pointerDesiredVelocity = 0
            // 主动行为结束后快速、平滑地刹停，避免残余惯性造成“站着滑”。
            physics.velocity.x *= pow(0.78, deltaTime * 60)
            if abs(physics.velocity.x) < 8 { physics.velocity.x = 0 }
        }

        guard abs(physics.velocity.x) >= 8 else {
            pointerChaseIsActive = false
            if let pendingActivityEvent {
                self.pendingActivityEvent = nil
                dispatch(pendingActivityEvent, source: "deferred-system")
            }
            return
        }

        let movingRight = physics.velocity.x > 0
        if isShooing || (isVisitingPointer && abs(physics.velocity.x) >= 175) {
            dispatch(movingRight ? .pointerChaseRight : .pointerChaseLeft, source: "locomotion-sync")
        } else if isVisitingPointer {
            dispatch(movingRight ? .pointerWalkRight : .pointerWalkLeft, source: "locomotion-sync")
        } else {
            // 刹停阶段也继续迈腿，直到速度真正归零，杜绝僵直滑动。
            dispatch(movingRight ? .autonomousWalkRight : .autonomousWalkLeft, source: "locomotion-sync")
        }
    }

    private func updateRenderedFrame() {
        guard let root = packageRoot, let animation = manifest?.animation(named: player.animationID), !animation.frames.isEmpty else { return }
        let passiveGaze = gazeUntil > CACurrentMediaTime() && behavior.active.priority <= .autonomous
        if passiveGaze { stepLookDirection() }
        let frame = animation.frames[min(player.frameIndex, animation.frames.count - 1)]
        let signedLookIndex = lookDirectionIndex <= 8 ? lookDirectionIndex : lookDirectionIndex - 16
        let eyeOffset = passiveGaze
            ? SIMD2<Float>(Float(signedLookIndex) * 1.4, 0)
            : .zero
        let bodyScale = frame.bodyScale ?? 1
        petView.displayFrame(
            url: root.appendingPathComponent(frame.image),
            textureRect: frame.textureRect,
            sourceSize: frame.sourceSize,
            pivot: frame.pivot,
            renderOffset: frame.renderOffset,
            canvasLayout: canvasLayout,
            bodyScale: bodyScale,
            flipHorizontally: interactionDirectionUntil > CACurrentMediaTime() && interactionFacesLeft,
            eyeOffsetPixels: eyeOffset
        )
        let scale = runtimeCanvasScale()
        let canvasSize = canvasLayout.size
        let size = NSSize(width: Double(canvasSize.width) * scale, height: Double(canvasSize.height) * scale)
        if let window, window.frame.size != size {
            let oldScaleX = window.frame.width / Double(canvasSize.width)
            let oldScaleY = window.frame.height / Double(canvasSize.height)
            let oldAnchor = NSPoint(
                x: window.frame.minX + canvasLayout.anchorFromTop.x * oldScaleX,
                y: window.frame.maxY - canvasLayout.anchorFromTop.y * oldScaleY
            )
            window.setContentSize(size)
            window.setFrameOrigin(NSPoint(
                x: oldAnchor.x - canvasLayout.anchorFromTop.x * scale,
                y: oldAnchor.y - (Double(canvasSize.height) - canvasLayout.anchorFromTop.y) * scale
            ))
            physics.position = .init(x: window.frame.minX, y: window.frame.minY)
        }
        currentFrame = frame
    }

    private func updateLookTarget(pointer: NSPoint, center: NSPoint) {
        let proposed = LookDirectionPolicy.passiveTargetIndex(
            pointerX: pointer.x,
            pointerY: pointer.y,
            centerX: center.x,
            centerY: center.y
        )
        let now = CACurrentMediaTime()
        if proposed != pendingLookDirectionIndex {
            pendingLookDirectionIndex = proposed
            pendingLookDirectionSince = now
        } else if now - pendingLookDirectionSince >= 0.24 {
            // Mouse samples can cross several angular bins in a few milliseconds.
            // Commit only a direction that has remained stable long enough to
            // prevent rapid left/right target reversals.
            targetLookDirectionIndex = proposed
        }
    }

    private func stepLookDirection() {
        guard lookDirectionIndex != targetLookDirectionIndex else { return }
        let now = CACurrentMediaTime()
        guard now - lastLookStepAt >= 0.28 else { return }
        lastLookStepAt = now
        let clockwise = (targetLookDirectionIndex - lookDirectionIndex + 16) % 16
        let step: Int
        if clockwise == 8 {
            // Horizontal left/right transitions should pass through the front/up center (index 0),
            // never through the down-facing poses where the eyes briefly disappear.
            step = (1...7).contains(lookDirectionIndex) ? 15 : 1
        } else {
            step = clockwise < 8 ? 1 : 15
        }
        lookDirectionIndex = (lookDirectionIndex + step) % 16
    }

    private func interactiveFrame(in window: NSWindow) -> NSRect {
        guard let frame = currentFrame else { return .zero }
        let interaction = frame.interactionRect
        let canvasSize = canvasLayout.size
        let scaleX = window.frame.width / Double(canvasSize.width)
        let scaleY = window.frame.height / Double(canvasSize.height)
        let bodyScale = frame.bodyScale ?? 1
        let origin = canvasLayout.origin(for: frame)
        return NSRect(
            x: window.frame.minX + (origin.x + Double(interaction.x) * bodyScale) * scaleX,
            y: window.frame.maxY - (origin.y + Double(interaction.y + interaction.height) * bodyScale) * scaleY,
            width: Double(interaction.width) * bodyScale * scaleX,
            height: Double(interaction.height) * bodyScale * scaleY
        )
    }

    private func resetSessionState(now: CFTimeInterval) {
        let origin = window?.frame.origin ?? .zero
        let core = PetSessionCoreState(
            replacing: sessionGeneration,
            contract: packageContract,
            position: .init(x: origin.x, y: origin.y)
        )
        sessionGeneration = core.generation
        behavior = core.behavior
        player = core.player
        physics = core.physics
        lastTimestamp = now
        lastPhysicsTimestamp = now
        dragSamples.removeAll()
        mouseDownPoint = nil
        isDragging = false
        currentFrame = nil
        lastPettingPoint = nil
        accumulatedPettingDistance = 0
        lookDirectionIndex = 0
        targetLookDirectionIndex = 0
        displayLinkIsThrottled = false
        pointerChaseIsActive = false
        pointerDesiredVelocity = 0
        mouseInterestUntil = 0
        nextMouseInterestAt = now + Double.random(in: 25...55)
        gazeUntil = 0
        gazeTrackingUntil = 0
        nextGazeAt = now + Double.random(in: 8...25)
        shooCooldownUntil = 0
        shooRunUntil = 0
        lastPointerSample = nil
        roamUntil = 0
        roamDirection = Bool.random() ? 1 : -1
        roamTargetX = nil
        roamIsRunning = false
        interactionFacesLeft = false
        interactionDirectionUntil = 0
        lastLookStepAt = 0
        pendingLookDirectionIndex = 0
        pendingLookDirectionSince = 0
        smoothedPointerSpeed = 0
        lastFastNearPointerAt = 0
        lastFastHorizontalDirection = 0
        fastNearReversalCount = 0
        autonomyScheduler = AutonomyScheduler(
            startTime: now,
            seed: UInt64.random(in: UInt64.min...UInt64.max)
        )
        pendingActivityEvent = nil
        pointerIntentRecognizer = PointerIntentRecognizer()
        lastPointerDiagnosticAt = 0
        petView.resetSession(generation: sessionGeneration)
        window?.ignoresMouseEvents = true
        diagnostics.log(category: "lifecycle", event: "pet-session-published", fields: [
            "generation": String(sessionGeneration),
            "petID": manifest?.id ?? "unknown",
        ])
    }

    private func updateMousePassthrough() {
        guard !isContextMenuOpen, !isDragging, let window else { return }
        window.ignoresMouseEvents = !interactiveFrame(in: window).contains(NSEvent.mouseLocation)
    }

    private func showContextMenu(for event: NSEvent) {
        isContextMenuOpen = true
        window?.ignoresMouseEvents = false
        defer {
            isContextMenuOpen = false
            updateMousePassthrough()
        }
        let menu = NSMenu(title: "猫上班了")
        for (title, value) in [("小（45%）", 0.45), ("中（65%）", 0.65), ("大（85%）", 0.85)] {
            let item = NSMenuItem(title: title, action: #selector(setScaleFromMenu(_:)), keyEquivalent: "")
            item.representedObject = value
            item.target = self
            item.state = abs(UserDefaults.standard.double(forKey: "petScale") - value) < 0.01 ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let chase = NSMenuItem(title: "偶尔靠近鼠标", action: #selector(toggleChaseFromMenu(_:)), keyEquivalent: "")
        chase.target = self
        chase.state = UserDefaults.standard.bool(forKey: "chasePointer") ? .on : .off
        chase.isEnabled = packageContract.supportsPointerLocomotion
        menu.addItem(chase)
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.popUp(positioning: nil, at: event.locationInWindow, in: petView)
    }

    @objc private func setScaleFromMenu(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(value, forKey: "petScale")
    }

    @objc private func toggleChaseFromMenu(_ sender: NSMenuItem) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "chasePointer"), forKey: "chasePointer")
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
