import XCTest
import CoreGraphics
@testable import Dimsum

final class WindowEnumeratorTests: XCTestCase {

    func testParseValidWindowInfo() {
        let enumerator = WindowEnumerator()
        let bounds: [String: CGFloat] = ["X": 100, "Y": 200, "Width": 800, "Height": 600]
        let dict: [CFString: Any] = [
            kCGWindowNumber: CGWindowID(42),
            kCGWindowOwnerPID: pid_t(999),
            kCGWindowOwnerName: "TestApp",
            kCGWindowBounds: bounds,
            kCGWindowLayer: 0,
            kCGWindowAlpha: CGFloat(1.0),
        ]

        let info = enumerator.parseWindowInfo(from: dict)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.windowID, 42)
        XCTAssertEqual(info?.ownerPID, 999)
        XCTAssertEqual(info?.ownerName, "TestApp")
        XCTAssertEqual(info?.layer, 0)
    }

    func testFilterNonZeroLayer() {
        let enumerator = WindowEnumerator()
        let bounds: [String: CGFloat] = ["X": 0, "Y": 0, "Width": 100, "Height": 100]
        let dict: [CFString: Any] = [
            kCGWindowNumber: CGWindowID(1),
            kCGWindowOwnerPID: pid_t(100),
            kCGWindowBounds: bounds,
            kCGWindowLayer: 25,
        ]

        let info = enumerator.parseWindowInfo(from: dict)
        XCTAssertNil(info, "Non-zero layer windows should be filtered out")
    }

    func testFilterOwnProcess() {
        let enumerator = WindowEnumerator()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let bounds: [String: CGFloat] = ["X": 0, "Y": 0, "Width": 100, "Height": 100]
        let dict: [CFString: Any] = [
            kCGWindowNumber: CGWindowID(1),
            kCGWindowOwnerPID: ownPID,
            kCGWindowBounds: bounds,
            kCGWindowLayer: 0,
        ]

        let info = enumerator.parseWindowInfo(from: dict)
        XCTAssertNil(info, "Own process windows should be filtered out")
    }

    func testMissingBoundsReturnsNil() {
        let enumerator = WindowEnumerator()
        let dict: [CFString: Any] = [
            kCGWindowNumber: CGWindowID(1),
            kCGWindowOwnerPID: pid_t(100),
            kCGWindowLayer: 0,
        ]

        let info = enumerator.parseWindowInfo(from: dict)
        XCTAssertNil(info)
    }
}
