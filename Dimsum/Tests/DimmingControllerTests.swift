import AppKit
import XCTest
@testable import Dimsum

/// Drives every user-facing dimming flow through the real preferences and real
/// overlay windows. See DimmingHarness for what is faked.
final class DimmingControllerTests: XCTestCase {
    private var harness: DimmingHarness!
    private var focusedWindow: NSWindow!

    private var preferences: PreferencesManager { harness.preferences }
    private var overlays: OverlayManager { harness.overlays }
    private var tracker: FakeWindowTracker { harness.tracker }
    private var scheduler: ManualScheduler { harness.scheduler }

    override func setUp() {
        super.setUp()
        NSApp.appearance = NSAppearance(named: .aqua)
        harness = DimmingHarness(testCase: self)
        focusedWindow = makeWindow()
        tracker.focusedWindowID = windowID(focusedWindow)
    }

    override func tearDown() {
        focusedWindow.close()
        NSApp.appearance = nil
        super.tearDown()
    }

    // MARK: - Launch

    func testLaunchWithPermissionDimsBehindFocusedWindow() {
        let controller = harness.makeController()
        controller.start()

        assertDimmed(behind: focusedWindow)
    }

    func testLaunchWithDimmingDisabledCreatesNoOverlays() {
        preferences.isDimmingEnabled = false
        let controller = harness.makeController()
        controller.start()

        XCTAssertFalse(controller.isDimming)
        XCTAssertEqual(overlays.overlayCount, 0)
    }

    func testLaunchWithoutPermissionPromptsThenDimsOnceGranted() {
        tracker.isTrusted = false
        let controller = harness.makeController()
        controller.start()

        XCTAssertEqual(harness.permissionNeededCount, 1)
        XCTAssertEqual(overlays.overlayCount, 0)

        scheduler.advance(by: 1)
        XCTAssertEqual(harness.permissionGrantedCount, 0, "Still untrusted, keep waiting")

        tracker.isTrusted = true
        scheduler.advance(by: 0.9)
        XCTAssertEqual(harness.permissionGrantedCount, 0, "Checks once a second")
        scheduler.advance(by: 0.1)
        XCTAssertEqual(harness.permissionGrantedCount, 1)
        assertDimmed(behind: focusedWindow)
    }

    // MARK: - Enable Dimming toggle

    func testTurningDimmingOffRemovesOverlays() {
        let controller = harness.makeController()
        controller.start()

        preferences.isDimmingEnabled = false

        XCTAssertFalse(controller.isDimming)
        XCTAssertEqual(overlays.overlayCount, 0)
    }

    func testTurningDimmingBackOnDimsAgain() {
        let controller = harness.makeController()
        controller.start()

        preferences.isDimmingEnabled = false
        preferences.isDimmingEnabled = true

        assertDimmed(behind: focusedWindow)
    }

    func testTurningDimmingOnAfterLaunchingDisabled() {
        preferences.isDimmingEnabled = false
        let controller = harness.makeController()
        controller.start()

        preferences.isDimmingEnabled = true

        assertDimmed(behind: focusedWindow)
    }

    func testTogglingRepeatedlyEndsInTheLastState() {
        let controller = harness.makeController()
        controller.start()

        for _ in 0..<3 {
            preferences.isDimmingEnabled = false
            preferences.isDimmingEnabled = true
        }
        scheduler.advance(by: 1)
        assertDimmed(behind: focusedWindow)

        preferences.isDimmingEnabled = false
        scheduler.advance(by: 1)
        XCTAssertEqual(overlays.overlayCount, 0)
    }

    // MARK: - Intensity and appearance

    func testIntensityChangeUpdatesOverlays() {
        let controller = harness.makeController()
        controller.start()

        preferences.dimmingIntensity = 0.3
        scheduler.advance(by: 1)

        assertAllOverlays(alpha: adaptedIntensity(base: 0.3, isDarkMode: false))
    }

    func testIntensityChangeWhileDisabledCreatesNoOverlays() {
        preferences.isDimmingEnabled = false
        let controller = harness.makeController()
        controller.start()

        preferences.dimmingIntensity = 0.3
        scheduler.advance(by: 1)

        XCTAssertEqual(overlays.overlayCount, 0)
    }

    func testSwitchingToDarkModeAdaptsIntensity() {
        let controller = harness.makeController()
        controller.start()

        NSApp.appearance = NSAppearance(named: .darkAqua)
        scheduler.advance(by: 1)

        assertAllOverlays(alpha: adaptedIntensity(base: preferences.dimmingIntensity, isDarkMode: true))
    }

    // MARK: - Focus

    func testFocusMovingToAnotherWindowFollowsIt() {
        let controller = harness.makeController()
        controller.start()

        let other = makeWindow()
        defer { other.close() }
        tracker.focusedWindowID = windowID(other)
        tracker.refreshFocusedWindow()

        assertDimmed(behind: other)
    }

    func testNoFocusedWindowHidesOverlaysAfterRetry() {
        let controller = harness.makeController()
        controller.start()

        tracker.focusedWindowID = nil
        tracker.refreshFocusedWindow()
        scheduler.advance(by: 0.4)
        assertAllOverlays(
            alpha: adaptedIntensity(base: preferences.dimmingIntensity, isDarkMode: false),
            "Waits for a late window before giving up"
        )

        scheduler.advance(by: 0.1)
        assertAllOverlays(alpha: 0)
    }

    func testFullScreenFrontmostAppHidesOverlays() throws {
        let screen = try XCTUnwrap(NSScreen.screens.first)
        harness.frontmostPID = 4242
        harness.enumerator.windows = [WindowInfo(
            windowID: 1,
            ownerPID: 4242,
            ownerName: "FullScreen",
            bounds: screen.frame,
            layer: 0,
            alpha: 1,
            isOnScreen: true
        )]
        let controller = harness.makeController()
        controller.start()

        assertAllOverlays(alpha: 0)
    }

    func testSpaceChangeResolvesFocusAgain() {
        let controller = harness.makeController()
        controller.start()

        let other = makeWindow()
        defer { other.close() }
        harness.workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        tracker.focusedWindowID = windowID(other)
        scheduler.advance(by: 1)

        assertDimmed(behind: other)
    }

    func testSpaceChangeToEmptyDesktopHidesOverlays() {
        let controller = harness.makeController()
        controller.start()

        harness.workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        tracker.focusedWindowID = nil
        scheduler.advance(by: 0.3)

        assertAllOverlays(alpha: 0)
    }

    func testFocusChangesDuringSpaceTransitionWaitForItToSettle() {
        let controller = harness.makeController()
        controller.start()
        let other = makeWindow()
        defer { other.close() }

        harness.workspaceCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        tracker.focusedWindowID = windowID(other)
        tracker.refreshFocusedWindow()
        scheduler.advance(by: 0.2)
        XCTAssertNotEqual(nextOwnWindow(below: other), overlays.overlayWindow(for: NSScreen.screens[0].displayID!)?.windowNumber)

        scheduler.advance(by: 0.1)
        assertDimmed(behind: other)
    }

    // MARK: - Sleep and screen changes

    func testScreenWakeRebuildsOverlaysLostDuringSleep() {
        let controller = harness.makeController()
        controller.start()

        overlays.removeAllOverlays()
        harness.workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        scheduler.advance(by: 1)

        assertDimmed(behind: focusedWindow)
    }

    func testScreenParameterChangeRebuildsOverlays() {
        let controller = harness.makeController()
        controller.start()

        overlays.removeAllOverlays()
        harness.appCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        scheduler.advance(by: 1)

        assertDimmed(behind: focusedWindow)
    }

    func testScreenWakeWhileDisabledCreatesNoOverlays() {
        let controller = harness.makeController()
        controller.start()
        preferences.isDimmingEnabled = false

        harness.workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        scheduler.advance(by: 1)

        XCTAssertEqual(overlays.overlayCount, 0)
    }

    // MARK: - Losing permission

    func testLosingPermissionStopsDimmingAndPrompts() {
        let controller = harness.makeController()
        controller.start()

        harness.revokePermission()

        XCTAssertFalse(controller.isDimming)
        XCTAssertFalse(tracker.isTracking)
        XCTAssertEqual(overlays.overlayCount, 0)
        XCTAssertEqual(harness.permissionNeededCount, 1)
    }

    func testDimmingResumesWhenPermissionComesBack() {
        let controller = harness.makeController()
        controller.start()
        harness.revokePermission()

        tracker.isTrusted = true
        scheduler.advance(by: 1)

        XCTAssertEqual(harness.permissionGrantedCount, 1)
        assertDimmed(behind: focusedWindow)
    }

    func testTogglingWhilePermissionIsLostKeepsOneWaiter() {
        let controller = harness.makeController()
        controller.start()
        harness.revokePermission()

        preferences.isDimmingEnabled = false
        preferences.isDimmingEnabled = true
        XCTAssertFalse(controller.isDimming)

        tracker.isTrusted = true
        scheduler.advance(by: 1)
        scheduler.advance(by: 1)

        XCTAssertEqual(harness.permissionGrantedCount, 1)
        assertDimmed(behind: focusedWindow)
    }

    func testShutdownRemovesOverlaysAndIgnoresLaterEvents() {
        let controller = harness.makeController()
        controller.start()

        controller.shutdown()
        preferences.isDimmingEnabled = false
        preferences.isDimmingEnabled = true
        harness.workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        scheduler.advance(by: 1)

        XCTAssertFalse(controller.isDimming)
        XCTAssertEqual(overlays.overlayCount, 0)
    }

    // MARK: - Helpers

    private func makeWindow() -> NSWindow {
        let frame = NSScreen.screens[0].visibleFrame
        let window = NSWindow(
            contentRect: NSRect(x: frame.minX + 100, y: frame.minY + 100, width: 300, height: 200),
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        waitUntil { self.windowServerInfo(for: window) != nil }
        return window
    }

    private func windowServerInfo(for window: NSWindow) -> [CFString: Any]? {
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID(window))
        return (info as? [[CFString: Any]])?.first
    }

    private func windowID(_ window: NSWindow) -> CGWindowID {
        CGWindowID(window.windowNumber)
    }

    private func assertDimmed(
        behind window: NSWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(overlays.overlayCount, NSScreen.screens.count, "One overlay per screen", file: file, line: line)
        assertAllOverlays(
            alpha: adaptedIntensity(base: preferences.dimmingIntensity, isDarkMode: false),
            file: file,
            line: line
        )

        // The window server's own stacking order: the overlay must sit right under the focused window.
        guard let displayID = NSScreen.screens[0].displayID,
              let overlay = overlays.overlayWindow(for: displayID) else {
            return XCTFail("No overlay on the focused window's screen", file: file, line: line)
        }
        guard windowServerInfo(for: window)?[kCGWindowIsOnscreen] as? Bool == true else {
            return XCTFail(
                "Test window is not on screen. Run tests from a regular desktop, not a full-screen Space.",
                file: file,
                line: line
            )
        }
        var nextInProcess: Int?
        waitUntil {
            nextInProcess = nextOwnWindow(below: window)
            return nextInProcess == overlay.windowNumber
        }
        XCTAssertEqual(
            nextInProcess,
            overlay.windowNumber,
            "Overlay is not directly behind the focused window",
            file: file,
            line: line
        )
    }

    /// The window server's stacking order: this process's next window under `window`.
    private func nextOwnWindow(below window: NSWindow) -> Int? {
        let below = CGWindowListCopyWindowInfo(
            [.optionOnScreenBelowWindow],
            windowID(window)
        ) as? [[CFString: Any]] ?? []
        return below.first {
            $0[kCGWindowOwnerPID] as? pid_t == ProcessInfo.processInfo.processIdentifier
        }?[kCGWindowNumber] as? Int
    }

    private func assertAllOverlays(
        alpha: Double,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(overlays.overlayCount, 0, "No overlays", file: file, line: line)
        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            XCTAssertEqual(
                Double(overlays.overlayAlpha(for: displayID) ?? -1),
                alpha,
                accuracy: 0.001,
                message,
                file: file,
                line: line
            )
        }
    }
}
