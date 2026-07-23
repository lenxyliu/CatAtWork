import Foundation

/// Maps a screen-space pointer position to the small, front-facing subset of
/// the 16-direction pose library. Ordinary gaze should move the eyes and head,
/// not turn the cat into a hard side profile or cross the tail-flip seam.
public enum LookDirectionPolicy {
    public static let directionCount = 16
    public static let maximumPassiveOffset = 2

    public static func passiveTargetIndex(
        pointerX: Double,
        pointerY: Double,
        centerX: Double,
        centerY: Double
    ) -> Int {
        let dx = pointerX - centerX
        let dy = pointerY - centerY
        let distance = hypot(dx, dy)
        guard distance >= 12, abs(dx) >= 10 else { return 0 }

        // A pointer below the cat adds a little downward head inclination, but
        // horizontal movement remains the deciding factor. This avoids choosing
        // an arbitrary left/right profile when the pointer is nearly centered.
        let horizontalAmount = abs(dx) / distance
        let downwardAmount = dy < 0 ? abs(dy) / distance : 0
        let magnitude = horizontalAmount + downwardAmount * 0.55
        let offset = min(
            maximumPassiveOffset,
            max(1, Int((magnitude * Double(maximumPassiveOffset)).rounded()))
        )
        return dx > 0 ? offset : directionCount - offset
    }
}
