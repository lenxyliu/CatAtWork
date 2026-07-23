import AppKit
import AVFoundation
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("usage: swift extract_video_contact.swift INPUT.mp4 OUTPUT.png [samples-per-second]\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let samplesPerSecond = CommandLine.arguments.count >= 4 ? max(1, Double(CommandLine.arguments[3]) ?? 4) : 4
let asset = AVURLAsset(url: input)
let semaphore = DispatchSemaphore(value: 0)
var resultCode = 0

Task {
    do {
        let duration = try await asset.load(.duration)
        let seconds = max(0, CMTimeGetSeconds(duration))
        guard seconds.isFinite, seconds > 0 else { throw CocoaError(.fileReadCorruptFile) }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let step = 1 / samplesPerSecond
        let sampleCount = max(1, Int(ceil(seconds / step)))
        let tileWidth = 320
        let tileHeight = 210
        let labelHeight = 24
        let columns = 4
        let rows = Int(ceil(Double(sampleCount) / Double(columns)))
        let canvas = NSImage(size: NSSize(width: columns * tileWidth, height: rows * (tileHeight + labelHeight)))
        canvas.lockFocus()
        NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
        NSRect(origin: .zero, size: canvas.size).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.black,
        ]
        for index in 0..<sampleCount {
            let requestedSeconds = min(seconds - 0.001, Double(index) * step)
            let requested = CMTime(seconds: requestedSeconds, preferredTimescale: 600)
            var actual = CMTime.zero
            let cgImage = try generator.copyCGImage(at: requested, actualTime: &actual)
            let image = NSImage(cgImage: cgImage, size: .zero)
            let column = index % columns
            let row = index / columns
            let x = column * tileWidth
            let y = rows * (tileHeight + labelHeight) - (row + 1) * (tileHeight + labelHeight)
            let sourceAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
            let tileAspect = CGFloat(tileWidth) / CGFloat(tileHeight)
            let drawSize = sourceAspect > tileAspect
                ? NSSize(width: CGFloat(tileWidth), height: CGFloat(tileWidth) / sourceAspect)
                : NSSize(width: CGFloat(tileHeight) * sourceAspect, height: CGFloat(tileHeight))
            let drawRect = NSRect(
                x: CGFloat(x) + (CGFloat(tileWidth) - drawSize.width) / 2,
                y: CGFloat(y + labelHeight) + (CGFloat(tileHeight) - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect)
            let actualSeconds = CMTimeGetSeconds(actual)
            String(format: "%05.2fs", actualSeconds).draw(
                at: NSPoint(x: x + 6, y: y + 4),
                withAttributes: attributes
            )
        }
        canvas.unlockFocus()

        guard let tiff = canvas.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: output, options: .atomic)
        print("wrote \(output.path) (\(sampleCount) samples, \(String(format: "%.2f", seconds))s)")
    } catch {
        fputs("video extraction failed: \(error)\n", stderr)
        resultCode = 1
    }
    semaphore.signal()
}

semaphore.wait()
exit(Int32(resultCode))
