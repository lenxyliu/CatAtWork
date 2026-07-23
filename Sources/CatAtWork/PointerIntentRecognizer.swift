import CatAtWorkCore
import Foundation

@MainActor
final class PetDiagnostics {
    static let shared = PetDiagnostics()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private(set) var logURL: URL?
    private let maximumBytes: UInt64 = 2 * 1_024 * 1_024

    private init() {
        guard let library = try? fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return }
        let directory = library.appendingPathComponent("Logs/猫上班了", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        logURL = directory.appendingPathComponent("interaction.jsonl")
        log(category: "lifecycle", event: "session-start", fields: [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-",
        ])
    }

    func log(category: String, event: String, fields: [String: String] = [:]) {
        guard let logURL else { return }
        rotateIfNeeded(logURL)
        var payload: [String: String] = [
            "time": ISO8601DateFormatter().string(from: .now),
            "monotonic": String(format: "%.3f", ProcessInfo.processInfo.systemUptime),
            "category": clean(category),
            "event": clean(event),
        ]
        for (key, value) in fields { payload[clean(key)] = clean(value) }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let newline = "\n".data(using: .utf8) else { return }
        if !fileManager.fileExists(atPath: logURL.path) { fileManager.createFile(atPath: logURL.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: newline)
        } catch { return }
    }

    private func rotateIfNeeded(_ url: URL) {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              UInt64(size) >= maximumBytes else { return }
        let previous = url.appendingPathExtension("1")
        try? fileManager.removeItem(at: previous)
        try? fileManager.moveItem(at: url, to: previous)
    }

    private func clean(_ value: String) -> String {
        String(value.replacingOccurrences(of: "\n", with: " ").prefix(120))
    }
}

extension PetEvent {
    var diagnosticName: String {
        switch self {
        case .tick: "tick"
        case .pointerApproached: "pointer-approached"
        case .pointerWalkLeft: "pointer-walk-left"
        case .pointerWalkRight: "pointer-walk-right"
        case .pointerChaseLeft: "pointer-chase-left"
        case .pointerChaseRight: "pointer-chase-right"
        case .shooLeft: "shoo-left"
        case .shooRight: "shoo-right"
        case .autonomousWalkLeft: "autonomous-walk-left"
        case .autonomousWalkRight: "autonomous-walk-right"
        case .autonomousRunLeft: "autonomous-run-left"
        case .autonomousRunRight: "autonomous-run-right"
        case .autonomousMicro(let id): "autonomous-micro-\(id)"
        case .autonomousAction(let id): "autonomous-action-\(id)"
        case .clicked: "clicked"
        case .petting: "petting"
        case .earsPetted: "ears-petted"
        case .chinPetted: "chin-petted"
        case .backPetted: "back-petted"
        case .bellyPetted: "belly-petted"
        case .previewAnimation(let id): "preview-\(id)"
        case .animationFinished(let id): "finished-\(id)"
        case .grabbed: "grabbed"
        case .thrown: "thrown"
        case .landed: "landed"
        case .userBecameActive: "user-active"
        case .userBecameIdle: "user-idle"
        case .workspaceCategory(let category): "workspace-\(category.rawValue)"
        case .chargingChanged: "charging-changed"
        case .batteryLevelChanged: "battery-changed"
        case .networkChanged: "network-changed"
        case .mediaPlaybackChanged: "media-changed"
        case .volumeChanged: "volume-changed"
        case .timePeriodChanged: "time-period-changed"
        case .lockChanged: "lock-changed"
        case .spaceChanged: "space-changed"
        case .wake: "wake"
        case .sleep: "sleep"
        }
    }

    var diagnosticFields: [String: String] {
        switch self {
        case .earsPetted(let left), .chinPetted(let left),
             .backPetted(let left), .bellyPetted(let left):
            ["pointerSide": left ? "left" : "right"]
        case .thrown(let velocity):
            [
                "throwVX": String(format: "%.0f", velocity.x),
                "throwVY": String(format: "%.0f", velocity.y),
            ]
        case .chargingChanged(let charging): ["charging": String(charging)]
        case .batteryLevelChanged(let level): ["batteryPercent": String(round(level * 100))]
        case .networkChanged(let connected): ["connected": String(connected)]
        case .mediaPlaybackChanged(let playing): ["playing": String(playing)]
        case .volumeChanged(let volume): ["volumePercent": String(round(volume * 100))]
        case .timePeriodChanged(let period): ["period": String(period)]
        case .lockChanged(let locked): ["locked": String(locked)]
        default: [:]
        }
    }
}
