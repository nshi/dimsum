import AppKit
import CoreGraphics

struct WindowInfo {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let bounds: CGRect
    let layer: Int
    let alpha: CGFloat
    let isOnScreen: Bool

    /// Convert CoreGraphics top-left-origin rect to AppKit bottom-left-origin rect.
    var nsRect: NSRect {
        guard let screenHeight = NSScreen.screens.first?.frame.height else {
            return NSRect(origin: .zero, size: bounds.size)
        }
        return NSRect(
            x: bounds.origin.x,
            y: screenHeight - bounds.origin.y - bounds.size.height,
            width: bounds.size.width,
            height: bounds.size.height
        )
    }
}
