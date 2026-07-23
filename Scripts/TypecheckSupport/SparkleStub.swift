// Minimal compile-time surface used only when the real Sparkle package cannot be resolved locally.
import AppKit

public final class SPUStandardUpdaterController {
    public init(startingUpdater: Bool, updaterDelegate: Any?, userDriverDelegate: Any?) {}
    public func checkForUpdates(_ sender: Any?) {}
}
