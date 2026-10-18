import AppKit
import XCTest
@testable import Dimsum

final class WindowTrackerTests: XCTestCase {
    func testDelegateCallbackWiring() {
        let tracker = WindowTracker()
        let mockDelegate = MockWindowTrackerDelegate()
        tracker.delegate = mockDelegate
        XCTAssertNotNil(tracker.delegate)
    }

    func testStopTrackingWithoutStart() {
        let tracker = WindowTracker()
        tracker.stopTracking()
    }

    func testAPIDisabledReportsPermissionLost() throws {
        let pid = try frontmostPID()
        let delegate = MockWindowTrackerDelegate()
        let tracker = WindowTracker(
            windowEnumerator: StubWindowEnumerator(windows: [window(id: 7, pid: pid)]),
            accessibility: FakeAccessibilityClient(result: .apiDisabled)
        )
        tracker.delegate = delegate

        tracker.refreshFocusedWindow()

        XCTAssertEqual(delegate.permissionLostCount, 1)
        XCTAssertEqual(delegate.callCount, 0)
    }

    func testBusyAppFallsBackToFrontmostWindow() throws {
        let pid = try frontmostPID()
        let delegate = MockWindowTrackerDelegate()
        let tracker = WindowTracker(
            windowEnumerator: StubWindowEnumerator(windows: [window(id: 7, pid: pid)]),
            accessibility: FakeAccessibilityClient(result: .cannotComplete)
        )
        tracker.delegate = delegate

        tracker.refreshFocusedWindow()

        XCTAssertEqual(delegate.permissionLostCount, 0)
        XCTAssertEqual(delegate.lastWindowID, 7)
    }

    private func frontmostPID() throws -> pid_t {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            throw XCTSkip("No frontmost application")
        }
        return pid
    }

    private func window(id: CGWindowID, pid: pid_t) -> WindowInfo {
        WindowInfo(
            windowID: id,
            ownerPID: pid,
            ownerName: "Test",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            layer: 0,
            alpha: 1,
            isOnScreen: true
        )
    }
}

private final class MockWindowTrackerDelegate: WindowTrackerDelegate {
    var lastWindowID: CGWindowID?
    var callCount = 0
    var permissionLostCount = 0

    func focusedWindowDidChange(to windowID: CGWindowID?) {
        lastWindowID = windowID
        callCount += 1
    }

    func accessibilityPermissionLost() {
        permissionLostCount += 1
    }
}

private struct FakeAccessibilityClient: AccessibilityClient {
    let result: AXError

    func copyAttributeValue(
        _ element: AXUIElement,
        _ attribute: String,
        _ value: inout CFTypeRef?
    ) -> AXError {
        result
    }
}
