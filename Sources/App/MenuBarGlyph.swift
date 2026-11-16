import AppKit

/// The menu-bar icon (fork): Vim's own cursor in a key outline, drawn as a template image so it
/// follows the menu bar's light and dark look. Each shape reads at 16 pt without colour:
/// - On in this app: bar (Insert and Replace, where keys type), block (Normal), block with a
///   selection band (Visual), faint block (no text field focused).
/// - Not working here: dimmed empty outline (app set to Off, or a permission missing),
///   slashed outline (Vim Mode off everywhere).
@MainActor
enum MenuBarGlyph {
    enum Shape: CaseIterable {
        case block, bar, visual, ghost, dimmed, slashed
    }

    static func shape(for icon: AppModel.Icon) -> Shape {
        switch icon {
        case .normal: .block
        case .insert, .replace: .bar
        case .visual: .visual
        case .idle: .ghost
        case .offHere, .permissionMissing: .dimmed
        case .off: .slashed
        }
    }

    private static var cache: [Shape: NSImage] = [:]

    static func image(for icon: AppModel.Icon) -> NSImage {
        let shape = shape(for: icon)
        if let image = cache[shape] { return image }
        // 22 × 18 pt, drawn in the same y-down units as the design's SVG.
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: true) { _ in
            draw(shape)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = icon.label
        cache[shape] = image
        return image
    }

    private static func draw(_ shape: Shape) {
        let ink = NSColor.black
        let frame = NSBezierPath(roundedRect: NSRect(x: 1.8, y: 1.8, width: 18.4, height: 14.4), xRadius: 3.6, yRadius: 3.6)
        frame.lineWidth = 1.6
        (shape == .slashed || shape == .dimmed ? ink.withAlphaComponent(0.45) : ink).setStroke()
        frame.stroke()
        ink.setFill()
        switch shape {
        case .block:
            NSBezierPath(roundedRect: NSRect(x: 8, y: 4.5, width: 6, height: 9), xRadius: 1, yRadius: 1).fill()
        case .bar:
            NSBezierPath(roundedRect: NSRect(x: 10.1, y: 4, width: 1.8, height: 10), xRadius: 0.9, yRadius: 0.9).fill()
        case .visual:
            ink.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: NSRect(x: 4, y: 5, width: 8.5, height: 8), xRadius: 1, yRadius: 1).fill()
            ink.setFill()
            NSBezierPath(roundedRect: NSRect(x: 12.5, y: 4.5, width: 5.5, height: 9), xRadius: 1, yRadius: 1).fill()
        case .ghost:
            ink.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: NSRect(x: 8, y: 4.5, width: 6, height: 9), xRadius: 1, yRadius: 1).fill()
        case .dimmed:
            break
        case .slashed:
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 3.5, y: 15.5))
            slash.line(to: NSPoint(x: 18.5, y: 2.5))
            slash.lineWidth = 1.6
            slash.lineCapStyle = .round
            ink.setStroke()
            slash.stroke()
        }
    }
}
