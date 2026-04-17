import XCTest
@testable import Dimsum

final class OverlayManagerTests: XCTestCase {
    private func makeManager() -> OverlayManager {
        let manager = OverlayManager()
        addTeardownBlock { manager.removeAllOverlays() }
        return manager
    }

    func testSetupOverlaysCreatesOnePerScreen() {
        let manager = makeManager()
        manager.setupOverlays()
        XCTAssertEqual(manager.overlayCount, NSScreen.screens.count)
    }

    func testRemoveAllOverlaysClearsDisplayMap() {
        let manager = makeManager()
        manager.setupOverlays()
        XCTAssertGreaterThan(manager.overlayCount, 0)
        manager.removeAllOverlays()
        XCTAssertEqual(manager.overlayCount, 0)
    }

    func testUpdateIntensityChangesAlpha() {
        let manager = makeManager()
        manager.setupOverlays()

        guard let displayID = NSScreen.screens.first?.displayID else {
            XCTFail("No display found")
            return
        }

        manager.updateIntensity(0.5, animated: false)
        XCTAssertEqual(manager.overlayAlpha(for: displayID), 0.5)

        manager.updateIntensity(0.8, animated: false)
        XCTAssertEqual(manager.overlayAlpha(for: displayID), 0.8)
    }

    func testHideAllOverlaysSetsAlphaToZero() {
        let manager = makeManager()
        manager.setupOverlays()
        manager.updateIntensity(0.5, animated: false)
        manager.hideAllOverlays()

        guard let displayID = NSScreen.screens.first?.displayID else {
            XCTFail("No display found")
            return
        }

        XCTAssertEqual(manager.overlayAlpha(for: displayID), 0)
    }

    func testRebuildOverlaysPreservesCount() {
        let manager = makeManager()
        manager.setupOverlays()
        let initialCount = manager.overlayCount
        manager.rebuildOverlays()
        XCTAssertEqual(manager.overlayCount, initialCount)
    }

    func testSetupOverlaysWindowProperties() {
        let manager = makeManager()
        manager.setupOverlays()

        guard let displayID = NSScreen.screens.first?.displayID else {
            XCTFail("No display found")
            return
        }

        guard let window = manager.overlayWindow(for: displayID) else {
            XCTFail("No overlay window found")
            return
        }

        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.hasShadow)
        XCTAssertFalse(window.isOpaque)
        XCTAssertEqual(window.level, .normal)
        XCTAssertTrue(window.collectionBehavior.contains(.transient))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenNone))
    }
}
