import AppKit
import SwiftUI
import XCTest
@testable import Dimsum

/// A virtual clock: scheduled work runs only when the test moves time past it.
final class ManualScheduler {
    private var now: TimeInterval = 0
    private var pending: [(fireAt: TimeInterval, work: DispatchWorkItem)] = []

    var schedule: DimmingController.Schedule {
        { [unowned self] delay, work in self.pending.append((self.now + delay, work)) }
    }

    /// Moves the clock forward, running work in time order as it comes due,
    /// including work scheduled along the way.
    func advance(by seconds: TimeInterval) {
        let end = now + seconds
        while let index = pending.indices
            .filter({ pending[$0].fireAt <= end })
            .min(by: { pending[$0].fireAt < pending[$1].fireAt }) {
            let item = pending.remove(at: index)
            now = item.fireAt
            if !item.work.isCancelled {
                item.work.perform()
            }
        }
        now = end
    }
}

/// Stands in for the Accessibility-based tracker. Like the real one, it reports
/// the focused window synchronously from startTracking and refreshFocusedWindow,
/// and reports lost permission when the process isn't trusted.
final class FakeWindowTracker: WindowTracking {
    weak var delegate: WindowTrackerDelegate?
    var focusedWindowID: CGWindowID?
    var isTrusted = true
    private(set) var isTracking = false

    func startTracking() throws {
        isTracking = true
        report()
    }

    func stopTracking() {
        isTracking = false
    }

    func refreshFocusedWindow() {
        report()
    }

    private func report() {
        if isTrusted {
            delegate?.focusedWindowDidChange(to: focusedWindowID)
        } else {
            delegate?.accessibilityPermissionLost()
        }
    }
}

final class StubWindowEnumerator: WindowEnumerating {
    var windows: [WindowInfo]

    init(windows: [WindowInfo] = []) {
        self.windows = windows
    }

    func visibleWindows() -> [WindowInfo] { windows }
}

/// Everything a DimmingController needs, with real preferences and real overlay
/// windows. Only the Accessibility tracker, the clock and the system
/// notification centers are fakes.
final class DimmingHarness {
    let preferences: PreferencesManager
    let overlays = OverlayManager()
    let tracker = FakeWindowTracker()
    let scheduler = ManualScheduler()
    let workspaceCenter = NotificationCenter()
    let appCenter = NotificationCenter()
    let enumerator = StubWindowEnumerator()
    var frontmostPID: pid_t?
    private(set) var permissionNeededCount = 0
    private(set) var permissionGrantedCount = 0
    private let suiteName = "com.dimsum.test.\(UUID().uuidString)"
    private var controllers: [DimmingController] = []

    init(testCase: XCTestCase) {
        preferences = PreferencesManager(defaults: UserDefaults(suiteName: suiteName)!)
        testCase.addTeardownBlock { [self] in
            controllers.forEach { $0.shutdown() }
            overlays.removeAllOverlays()
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }

    func makeController() -> DimmingController {
        let controller = DimmingController(
            preferences: preferences,
            overlayManager: overlays,
            windowEnumerator: enumerator,
            makeTracker: { [tracker] in tracker },
            isTrusted: { [tracker] in tracker.isTrusted },
            frontmostPID: { [unowned self] in self.frontmostPID },
            workspaceCenter: workspaceCenter,
            appCenter: appCenter,
            schedule: scheduler.schedule
        )
        controller.onPermissionNeeded = { [unowned self] in self.permissionNeededCount += 1 }
        controller.onPermissionGranted = { [unowned self] in self.permissionGrantedCount += 1 }
        controllers.append(controller)
        return controller
    }

    /// macOS stops trusting the app; the tracker notices on its next lookup.
    func revokePermission() {
        tracker.isTrusted = false
        tracker.refreshFocusedWindow()
    }
}

/// Turns the run loop until `condition` holds or two seconds pass. AppKit hands
/// windows to the window server, and SwiftUI builds AppKit-backed controls, only
/// as the run loop turns.
@discardableResult
func waitUntil(_ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(2)
    while !condition() {
        guard Date() < deadline else { return false }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    return true
}

/// Hosts a SwiftUI view in an on-screen window, so its controls can be found
/// with findAccessibilityElement.
func hostOnScreen<V: View>(_ view: V, size: NSSize = NSSize(width: 280, height: 400)) -> (NSWindow, NSView) {
    let hostingView = NSHostingView(rootView: view)
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = hostingView
    window.orderFrontRegardless()
    return (window, hostingView)
}

/// AppKit builds SwiftUI's accessibility tree only once an Accessibility client
/// has sent the app a request. Where none has (CI), a request from ourselves is
/// enough. AppKit answers that it doesn't support this attribute, so nothing
/// else changes.
private let activateAccessibility: Void = {
    _ = AXUIElementSetAttributeValue(
        AXUIElementCreateApplication(getpid()),
        "AXEnhancedUserInterface" as CFString,
        kCFBooleanTrue
    )
}()

/// Every accessibility element under `root`. SwiftUI's nodes are private types,
/// so they are queried through dynamic lookup.
func accessibilityElements(under root: AnyObject) -> [AnyObject] {
    activateAccessibility
    var seen = Set<ObjectIdentifier>()
    var result: [AnyObject] = []
    func visit(_ element: AnyObject) {
        guard seen.insert(ObjectIdentifier(element)).inserted else { return }
        result.append(element)
        for child in element.accessibilityChildren?() ?? [] {
            visit(child as AnyObject)
        }
        // SwiftUI embeds some controls (switches, sliders) as AppKit views.
        for subview in (element as? NSView)?.subviews ?? [] {
            visit(subview)
        }
    }
    visit(root)
    return result
}

/// Waits for the element under `root` that matches, since SwiftUI fills in its
/// accessibility tree a few run loop turns after layout.
func findAccessibilityElement(under root: AnyObject, where matches: (AnyObject) -> Bool) -> AnyObject? {
    var found: AnyObject?
    waitUntil {
        found = accessibilityElements(under: root).first(where: matches)
        return found != nil
    }
    return found
}

func accessibilityLabel(of element: AnyObject) -> String? {
    element.accessibilityLabel?() ?? element.accessibilityTitle?()
}
