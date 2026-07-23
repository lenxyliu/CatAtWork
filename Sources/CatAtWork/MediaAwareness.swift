import CatAtWorkCore
import Foundation

/// Optional, user-enabled Apple Event polling. It reads only player state, never track metadata.
@MainActor
final class MediaAwareness {
    var onEvent: ((PetEvent) -> Void)?
    private var timer: Timer?
    private var lastPlaying: Bool?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let scripts = [
            "tell application \"System Events\" to if exists process \"Music\" then tell application \"Music\" to return player state as string",
            "tell application \"System Events\" to if exists process \"Spotify\" then tell application \"Spotify\" to return player state as string",
        ]
        let playing = scripts.contains { source in
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
            return error == nil && result?.lowercased().contains("playing") == true
        }
        guard playing != lastPlaying else { return }
        lastPlaying = playing
        onEvent?(.mediaPlaybackChanged(playing))
    }
}
