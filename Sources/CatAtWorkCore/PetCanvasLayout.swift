import Foundation

public struct PixelPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A transparent canvas large enough to place every variable-size frame on the
/// same world anchor without clipping. `anchorFromTop` uses image coordinates.
public struct PetCanvasLayout: Hashable, Sendable {
    public var size: PixelSize
    public var anchorFromTop: PixelPoint
    public var margin: Double

    public init(frames: [PetFrame], margin: Double = 16) {
        let safeMargin = max(0, margin)
        var left = 0.0
        var right = 0.0
        var top = 0.0
        var bottom = 0.0

        for frame in frames {
            let scale = frame.bodyScale ?? 1
            let width = Double(frame.sourceSize.width) * scale
            let height = Double(frame.sourceSize.height) * scale
            let offsetX = (frame.renderOffset?.x ?? 0) * scale
            let offsetY = (frame.renderOffset?.y ?? 0) * scale
            left = max(left, frame.pivot.x * width - offsetX)
            right = max(right, (1 - frame.pivot.x) * width + offsetX)
            top = max(top, frame.pivot.y * height - offsetY)
            bottom = max(bottom, (1 - frame.pivot.y) * height + offsetY)
        }

        if frames.isEmpty {
            size = PixelSize(width: 320, height: 320)
            anchorFromTop = PixelPoint(x: 160, y: 304)
            self.margin = safeMargin
            return
        }

        size = PixelSize(
            width: max(1, Int(ceil(left + right + safeMargin * 2))),
            height: max(1, Int(ceil(top + bottom + safeMargin * 2)))
        )
        anchorFromTop = PixelPoint(x: safeMargin + left, y: safeMargin + top)
        self.margin = safeMargin
    }

    public func origin(for frame: PetFrame) -> PixelPoint {
        let scale = frame.bodyScale ?? 1
        return PixelPoint(
            x: anchorFromTop.x - frame.pivot.x * Double(frame.sourceSize.width) * scale +
                (frame.renderOffset?.x ?? 0) * scale,
            y: anchorFromTop.y - frame.pivot.y * Double(frame.sourceSize.height) * scale +
                (frame.renderOffset?.y ?? 0) * scale
        )
    }

    /// Converts the shared foot/body anchor into an NSWindow bottom-left
    /// origin. The transparent safety area below the anchor may sit offscreen;
    /// it must not lift the visible cat above the desktop floor.
    public func windowOriginY(placingAnchorAt worldY: Double, scale: Double) -> Double {
        worldY - (Double(size.height) - anchorFromTop.y) * scale
    }

    public func anchorWorldY(forWindowOriginY originY: Double, scale: Double) -> Double {
        originY + (Double(size.height) - anchorFromTop.y) * scale
    }
}
