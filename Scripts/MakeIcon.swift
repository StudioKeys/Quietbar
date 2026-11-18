import AppKit

let canvas: CGFloat = 1024
let inset: CGFloat = 100
let tileRect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let cornerRadius: CGFloat = 185

func drawIcon() -> NSImage {
    NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
        let tile = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 28
        shadow.set()
        NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.22, alpha: 1).setFill()
        tile.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGradient(
            colors: [
                NSColor(calibratedRed: 0.29, green: 0.23, blue: 1.00, alpha: 1),
                NSColor(calibratedRed: 0.88, green: 0.27, blue: 0.56, alpha: 1),
            ]
        )?.draw(in: tile, angle: -60)

        let sheen = NSBezierPath(roundedRect: tileRect.insetBy(dx: 18, dy: 18), xRadius: 168, yRadius: 168)
        NSGradient(
            colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)]
        )?.draw(in: sheen, angle: -90)

        drawMonogram()
        return true
    }
}

func drawMonogram() {
    NSColor.white.setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 299, y: 341, width: 398, height: 398))
    ring.lineWidth = 62
    ring.stroke()

    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 560, y: 470))
    tail.line(to: NSPoint(x: 740, y: 300))
    tail.lineWidth = 69
    tail.lineCapStyle = .round
    tail.stroke()
}

func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
    else { throw CocoaError(.fileWriteUnknown) }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let icon = drawIcon()
for points in [16, 32, 128, 256, 512] {
    try writePNG(icon, pixels: points, to: output.appendingPathComponent("icon_\(points)x\(points).png"))
    try writePNG(icon, pixels: points * 2, to: output.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
