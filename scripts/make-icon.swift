// Renders AppIcon.icns. Run from the repo root: swift scripts/make-icon.swift
// Same pyramid as MenuBarIcon, in dollar-bill colors, on Apple's 1024pt icon grid.
import AppKit

func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    color(0x0F3325).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: color(0x2C7150), ending: color(0x0E2F22))!.draw(in: tile, angle: -90)

    // Glory rays behind the capstone.
    let center = NSPoint(x: 512, y: 700)
    color(0xF7D774, 0.10).setFill()
    for i in 0..<18 {
        let a = CGFloat(i) / 18 * 2 * .pi
        let ray = NSBezierPath()
        ray.move(to: center)
        ray.line(to: NSPoint(x: center.x + 900 * cos(a - 0.06), y: center.y + 900 * sin(a - 0.06)))
        ray.line(to: NSPoint(x: center.x + 900 * cos(a + 0.06), y: center.y + 900 * sin(a + 0.06)))
        ray.close()
        ray.fill()
    }
    // Fade the rays out away from the capstone.
    NSGradient(colors: [color(0x0E2F22, 0), color(0x0E2F22, 0.9)])!
        .draw(fromCenter: center, radius: 60, toCenter: center, radius: 560, options: .drawsAfterEndingLocation)
    NSGraphicsContext.restoreGraphicsState()

    // Pyramid body, with the waveform cut in.
    let body = NSBezierPath()
    body.move(to: NSPoint(x: 372, y: 522))
    body.line(to: NSPoint(x: 652, y: 522))
    body.line(to: NSPoint(x: 792, y: 260))
    body.line(to: NSPoint(x: 232, y: 260))
    body.close()
    NSGradient(starting: color(0xF6EED6), ending: color(0xD6C392))!.draw(in: body, angle: -90)

    let wave = NSBezierPath()
    wave.lineWidth = 52
    wave.lineCapStyle = .round
    for (x, h) in [(407.0, 26.0), (512.0, 52.0), (617.0, 26.0)] as [(CGFloat, CGFloat)] {
        wave.move(to: NSPoint(x: x, y: 388 - h))
        wave.line(to: NSPoint(x: x, y: 388 + h))
    }
    color(0x16402D).setStroke()
    wave.stroke()

    // Glowing capstone.
    let cap = NSBezierPath()
    cap.move(to: NSPoint(x: 512, y: 780))
    cap.line(to: NSPoint(x: 612, y: 606))
    cap.line(to: NSPoint(x: 412, y: 606))
    cap.close()
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(0xFFD35A, 0.8)
    glow.shadowBlurRadius = 60
    glow.set()
    color(0xF2B83A).setFill()
    cap.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0xFFE08A), ending: color(0xE09B1E))!.draw(in: cap, angle: -90)
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / 1024
    NSAffineTransform(transform: AffineTransform(scaleByX: scale, byY: scale)).concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! png(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! png(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let iconutil = try! Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"),
                                arguments: ["-c", "icns", iconset.path, "-o", "AppIcon.icns"])
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote AppIcon.icns" : "iconutil failed")
