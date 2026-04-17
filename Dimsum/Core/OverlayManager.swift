import AppKit

final class OverlayManager: OverlayManaging {
    private var displayOverlays: [CGDirectDisplayID: ScreenOverlay] = [:]
    private let animationDuration: TimeInterval = 0.35

    // MARK: - OverlayManaging

    func setupOverlays() {
        removeAllOverlays()
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let overlay = createOverlayWindow(for: screen)
            displayOverlays[displayID] = ScreenOverlay(
                window: overlay,
                targetAlpha: 0
            )
        }
    }

    func orderBehind(windowID: CGWindowID, intensity: Double, animated: Bool) {
        guard let targetDisplay = displayContaining(windowID: windowID) else {
            hideAllOverlays()
            return
        }

        let alpha = CGFloat(intensity)
        for (displayID, overlay) in displayOverlays {
            if displayID == targetDisplay {
                overlay.window.order(.below, relativeTo: Int(windowID))
            } else {
                overlay.window.orderFront(nil)
            }
            applyAlpha(alpha, on: overlay, animated: animated)
        }
    }

    func updateIntensity(_ intensity: Double, animated: Bool) {
        let alpha = CGFloat(intensity)
        for (_, overlay) in displayOverlays {
            applyAlpha(alpha, on: overlay, animated: animated)
        }
    }

    func hideAllOverlays() {
        for (_, overlay) in displayOverlays {
            applyAlpha(0, on: overlay, animated: true)
        }
    }

    func removeAllOverlays() {
        for displayID in displayOverlays.keys {
            tearDownOverlay(for: displayID)
        }
    }

    func rebuildOverlays() {
        let currentDisplayIDs = Set(NSScreen.screens.compactMap(\.displayID))
        let existingDisplayIDs = Set(displayOverlays.keys)

        for displayID in existingDisplayIDs.subtracting(currentDisplayIDs) {
            tearDownOverlay(for: displayID)
        }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            if displayOverlays[displayID] == nil {
                let overlay = createOverlayWindow(for: screen)
                displayOverlays[displayID] = ScreenOverlay(
                    window: overlay,
                    targetAlpha: 0
                )
            } else {
                displayOverlays[displayID]?.window.setFrame(screen.frame, display: false)
            }
        }
    }

    // MARK: - Internal (for testing)

    var overlayCount: Int { displayOverlays.count }

    func overlayAlpha(for displayID: CGDirectDisplayID) -> CGFloat? {
        displayOverlays[displayID]?.targetAlpha
    }

    func overlayWindow(for displayID: CGDirectDisplayID) -> NSWindow? {
        displayOverlays[displayID]?.window
    }

    // MARK: - Private

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.alphaValue = 0
        window.level = .normal
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isOpaque = false
        window.collectionBehavior = [.transient, .fullScreenNone]
        return window
    }

    private func tearDownOverlay(for displayID: CGDirectDisplayID) {
        displayOverlays[displayID]?.window.orderOut(nil)
        displayOverlays[displayID]?.window.close()
        displayOverlays.removeValue(forKey: displayID)
    }

    private func applyAlpha(_ alpha: CGFloat, on overlay: ScreenOverlay, animated: Bool) {
        guard overlay.targetAlpha != alpha else { return }
        overlay.targetAlpha = alpha
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                overlay.window.animator().alphaValue = alpha
            }
        } else {
            overlay.window.alphaValue = alpha
        }
    }

    private func displayContaining(windowID: CGWindowID) -> CGDirectDisplayID? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            windowID
        ) as? [[CFString: Any]],
              let first = windowInfo.first,
              let boundsDict = first[kCGWindowBounds] as? [String: CGFloat],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else {
            return nil
        }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            if screen.cgRect.contains(center) {
                return displayID
            }
        }

        return NSScreen.screens.first?.displayID
    }
}

private final class ScreenOverlay {
    let window: NSWindow
    var targetAlpha: CGFloat

    init(window: NSWindow, targetAlpha: CGFloat) {
        self.window = window
        self.targetAlpha = targetAlpha
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Screen frame in CoreGraphics coordinates (top-left origin).
    var cgRect: CGRect {
        guard let main = NSScreen.screens.first else { return frame }
        return CGRect(
            x: frame.origin.x,
            y: main.frame.height - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }
}
