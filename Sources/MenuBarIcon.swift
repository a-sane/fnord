import AppKit

/// The fnord glyph: an Illuminatus pyramid with a mark where the eye would be.
/// Drawn in code as a template image so it follows the menu bar's appearance.
enum MenuBarIcon {
    enum Mark { case wave, dots, bang }

    static func image(_ mark: Mark, filled: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            // Floating capstone, always solid.
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: 9, y: 16.75))
            cap.line(to: NSPoint(x: 11.75, y: 12))
            cap.line(to: NSPoint(x: 6.25, y: 12))
            cap.close()
            cap.fill()

            let body = NSBezierPath()
            body.move(to: NSPoint(x: 5.25, y: 9.75))
            body.line(to: NSPoint(x: 12.75, y: 9.75))
            body.line(to: NSPoint(x: 17, y: 2.25))
            body.line(to: NSPoint(x: 1, y: 2.25))
            body.close()
            body.lineWidth = 1.5
            body.lineJoinStyle = .miter
            body.stroke()
            if filled { body.fill() }

            let marks = NSBezierPath()
            marks.lineWidth = 1.5
            marks.lineCapStyle = .round
            switch mark {
            case .wave:
                for (x, h) in [(6.0, 0.75), (9.0, 1.5), (12.0, 0.75)] as [(CGFloat, CGFloat)] {
                    marks.move(to: NSPoint(x: x, y: 5.9 - h))
                    marks.line(to: NSPoint(x: x, y: 5.9 + h))
                }
            case .dots:
                for x in [6.0, 9.0, 12.0] as [CGFloat] {
                    marks.move(to: NSPoint(x: x, y: 5.9))
                    marks.line(to: NSPoint(x: x, y: 5.9))
                }
            case .bang:
                marks.move(to: NSPoint(x: 9, y: 6.5))
                marks.line(to: NSPoint(x: 9, y: 7.75))
                marks.move(to: NSPoint(x: 9, y: 4))
                marks.line(to: NSPoint(x: 9, y: 4))
            }
            // Knock the mark out of a filled pyramid instead of painting over it.
            if filled { NSGraphicsContext.current?.compositingOperation = .clear }
            marks.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
