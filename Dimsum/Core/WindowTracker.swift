import ApplicationServices
import AppKit

final class WindowTracker: WindowTracking {
    weak var delegate: WindowTrackerDelegate?

    private var appObserver: AXObserver?
    private var trackedPID: pid_t = 0
    private var workspaceObserver: NSObjectProtocol?
    private let windowEnumerator: WindowEnumerating

    init(windowEnumerator: WindowEnumerating = WindowEnumerator()) {
        self.windowEnumerator = windowEnumerator
    }

    deinit {
        stopTracking()
    }

    func startTracking() throws {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppActivated()
        }

        handleAppActivated()
    }

    func stopTracking() {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        tearDownAppObserver()
    }

    // MARK: - App Activation

    private func handleAppActivated() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            delegate?.focusedWindowDidChange(to: nil)
            return
        }

        let pid = app.processIdentifier
        if pid != trackedPID {
            tearDownAppObserver()
            setupAppObserver(for: pid)
        }

        resolveFocusedWindow()
    }

    private func setupAppObserver(for pid: pid_t) {
        var obs: AXObserver?
        guard AXObserverCreate(pid, axCallback, &obs) == .success,
              let obs else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let appElement = AXUIElementCreateApplication(pid)

        AXObserverAddNotification(
            obs,
            appElement,
            kAXFocusedWindowChangedNotification as CFString,
            selfPtr
        )

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .commonModes
        )

        appObserver = obs
        trackedPID = pid
    }

    private func tearDownAppObserver() {
        if let obs = appObserver {
            let appElement = AXUIElementCreateApplication(trackedPID)
            AXObserverRemoveNotification(
                obs,
                appElement,
                kAXFocusedWindowChangedNotification as CFString
            )
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(obs),
                .commonModes
            )
        }
        appObserver = nil
        trackedPID = 0
    }

    // MARK: - Focus Resolution

    func refreshFocusedWindow() {
        resolveFocusedWindow()
    }

    fileprivate func resolveFocusedWindow() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            delegate?.focusedWindowDidChange(to: nil)
            return
        }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if result == .success, let focusedWindow {
            let axWindow = focusedWindow as! AXUIElement
            if let position = axPosition(of: axWindow),
               let size = axSize(of: axWindow) {
                let windowID = findWindowID(pid: pid, position: position, size: size)
                delegate?.focusedWindowDidChange(to: windowID)
                return
            }
        }

        // AX failed (e.g. Electron apps return kAXErrorCannotComplete).
        // Fall back to the frontmost CG window for this PID.
        let fallbackID = windowEnumerator.visibleWindows()
            .first { $0.ownerPID == pid }?.windowID
        delegate?.focusedWindowDidChange(to: fallbackID)
    }

    // MARK: - AXUIElement attribute helpers

    private func axPosition(of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
              let value else { return nil }
        let axValue = value as! AXValue
        var point = CGPoint.zero
        AXValueGetValue(axValue, .cgPoint, &point)
        return point
    }

    private func axSize(of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let value else { return nil }
        let axValue = value as! AXValue
        var size = CGSize.zero
        AXValueGetValue(axValue, .cgSize, &size)
        return size
    }

    private func findWindowID(pid: pid_t, position: CGPoint, size: CGSize) -> CGWindowID? {
        let windows = windowEnumerator.visibleWindows()
        let tolerance: CGFloat = 2.0

        for window in windows where window.ownerPID == pid {
            if abs(window.bounds.origin.x - position.x) < tolerance
                && abs(window.bounds.origin.y - position.y) < tolerance
                && abs(window.bounds.size.width - size.width) < tolerance
                && abs(window.bounds.size.height - size.height) < tolerance {
                return window.windowID
            }
        }

        return nil
    }

}

private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        tracker.resolveFocusedWindow()
    }
}
