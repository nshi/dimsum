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
}

private final class MockWindowTrackerDelegate: WindowTrackerDelegate {
    var lastWindowID: CGWindowID?
    var callCount = 0

    func focusedWindowDidChange(to windowID: CGWindowID?) {
        lastWindowID = windowID
        callCount += 1
    }
}
