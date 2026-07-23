import AppKit
import ApplicationServices
import CatAtWorkCore
import CoreAudio
import IOKit.ps
import Network

@MainActor
final class SystemAwareness {
    var onEvent: ((PetEvent) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var inputMonitors: [Any] = []
    private var activityTimer: Timer?
    private var batteryTimer: Timer?
    private var contextTimer: Timer?
    private var lastInputAt = Date()
    private var userWasActive = true
    private var charging: Bool?
    private var batteryLevel: Double?
    private var lastHour: Int?
    private var lastVolume: Float32?
    private var lastWorkspaceCategory: WorkspaceCategory?
    private var networkConnected: Bool?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "app.catatwork.network-monitor")
    private let classifier = WorkspaceClassifier()

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in self?.classify(app: app) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onEvent?(.wake) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onEvent?(.sleep) }
        })
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onEvent?(.spaceChanged) }
        })
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onEvent?(.lockChanged(true)) }
        })
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onEvent?(.lockChanged(false)) }
        })
        if let input = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel], handler: { [weak self] _ in
            Task { @MainActor in self?.lastInputAt = .now }
        }) {
            inputMonitors.append(input)
        }
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollActivity() }
        }
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollBattery() }
        }
        contextTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollTimeAndVolume()
                self?.pollFrontmostApplication()
            }
        }
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.handleNetwork(connected) }
        }
        networkMonitor.start(queue: networkQueue)
        pollBattery()
        pollTimeAndVolume()
        pollFrontmostApplication()
        pollLockState()
    }

    func requestAccessibilityIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach {
            center.removeObserver($0)
            DistributedNotificationCenter.default().removeObserver($0)
        }
        observers.removeAll()
        inputMonitors.forEach(NSEvent.removeMonitor)
        inputMonitors.removeAll()
        activityTimer?.invalidate()
        activityTimer = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        contextTimer?.invalidate()
        contextTimer = nil
        networkMonitor.cancel()
    }

    private func classify(app: NSRunningApplication) {
        var title: String?
        if AXIsProcessTrusted() {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var focused: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused) == .success,
               let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
                var value: CFTypeRef?
                let focusedElement = unsafeDowncast(focused, to: AXUIElement.self)
                if AXUIElementCopyAttributeValue(focusedElement, kAXTitleAttribute as CFString, &value) == .success {
                    title = value as? String
                }
            }
        }
        // The title is intentionally discarded immediately after local classification.
        let category = classifier.classify(bundleIdentifier: app.bundleIdentifier, windowTitle: title)
        guard let previous = lastWorkspaceCategory else {
            lastWorkspaceCategory = category
            onEvent?(.workspaceCategory(category))
            return
        }
        guard category != previous else { return }
        lastWorkspaceCategory = category
        onEvent?(.workspaceCategory(category))
    }

    private func pollFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        classify(app: app)
    }

    private func pollActivity() {
        let active = Date().timeIntervalSince(lastInputAt) < 8
        guard active != userWasActive else { return }
        userWasActive = active
        onEvent?(active ? .userBecameActive : .userBecameIdle)
    }

    private func pollBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }
        let isCharging = sources.contains { source in
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return false }
            let state = description[kIOPSPowerSourceStateKey] as? String
            return state == kIOPSACPowerValue
        }
        if charging == nil || charging != isCharging {
            onEvent?(.chargingChanged(isCharging))
        }
        charging = isCharging
        let capacities = sources.compactMap { source -> Double? in
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
                  let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
                  maximum.doubleValue > 0 else { return nil }
            return current.doubleValue / maximum.doubleValue
        }
        if let level = capacities.min() {
            if batteryLevel == nil || abs((batteryLevel ?? level) - level) >= 0.05 {
                onEvent?(.batteryLevelChanged(level))
            }
            batteryLevel = level
        }
    }

    private func pollTimeAndVolume() {
        let hour = Calendar.current.component(.hour, from: .now)
        if lastHour == nil || lastHour != hour {
            onEvent?(.timePeriodChanged(hour))
        }
        lastHour = hour
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &size, &deviceID) == noErr else { return }
        var volume = Float32(0)
        size = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &size, &volume) == noErr else { return }
        if lastVolume == nil || abs((lastVolume ?? volume) - volume) >= 0.08 {
            onEvent?(.volumeChanged(Double(volume)))
        }
        lastVolume = volume
    }

    private func handleNetwork(_ connected: Bool) {
        if networkConnected == nil || networkConnected != connected {
            onEvent?(.networkChanged(connected))
        }
        networkConnected = connected
    }

    private func pollLockState() {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let locked = session["CGSSessionScreenIsLocked"] as? Bool else { return }
        onEvent?(.lockChanged(locked))
    }
}
