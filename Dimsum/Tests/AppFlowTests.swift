import AppKit
import SwiftUI
import XCTest
@testable import Dimsum

/// Drives the app the way a user does: through the menu bar button, the
/// popover's controls and the permission prompt, with AppDelegate's own wiring.
final class AppFlowTests: XCTestCase {
    private var harness: DimmingHarness!

    override func setUp() {
        super.setUp()
        harness = DimmingHarness(testCase: self)
    }

    func testEnableDimmingSwitchStopsAndRestartsDimming() throws {
        let (app, controller) = launchApp()
        XCTAssertTrue(controller.isDimming)

        let popoverView = try showPopoverContent(of: app)
        let toggle = try XCTUnwrap(
            findAccessibilityElement(under: popoverView) {
                $0.accessibilityIdentifier?() == "enableDimming"
                    && $0.accessibilityRole?() == .checkBox
            },
            "No Enable Dimming switch in the popover"
        )

        _ = toggle.accessibilityPerformPress?()
        XCTAssertFalse(harness.preferences.isDimmingEnabled)
        XCTAssertFalse(controller.isDimming)
        XCTAssertEqual(harness.overlays.overlayCount, 0)

        _ = toggle.accessibilityPerformPress?()
        XCTAssertTrue(harness.preferences.isDimmingEnabled)
        XCTAssertTrue(controller.isDimming)
        XCTAssertTrue(harness.tracker.isTracking)
        XCTAssertEqual(harness.overlays.overlayCount, NSScreen.screens.count)
    }

    func testEnableDimmingSwitchIsLabeledForVoiceOver() throws {
        let (app, _) = launchApp()
        let popoverView = try showPopoverContent(of: app)
        let toggle = try XCTUnwrap(findAccessibilityElement(under: popoverView) {
            $0.accessibilityIdentifier?() == "enableDimming" && $0.accessibilityRole?() == .checkBox
        })

        XCTAssertEqual(accessibilityLabel(of: toggle), "Enable Dimming")
    }

    func testPermissionPromptShowsUntilGrantedThenSettings() {
        harness.tracker.isTrusted = false
        let (app, controller) = launchApp()

        XCTAssertTrue(app.popover.contentViewController is NSHostingController<PermissionView>)
        XCTAssertFalse(controller.isDimming)

        harness.tracker.isTrusted = true
        harness.scheduler.advance(by: 1)

        XCTAssertTrue(app.popover.contentViewController is NSHostingController<PopoverView>)
        XCTAssertTrue(controller.isDimming)
    }

    func testLosingPermissionBringsBackThePrompt() {
        let (app, controller) = launchApp()
        XCTAssertTrue(app.popover.contentViewController is NSHostingController<PopoverView>)

        harness.revokePermission()

        XCTAssertTrue(app.popover.contentViewController is NSHostingController<PermissionView>)
        XCTAssertFalse(controller.isDimming)
    }

    /// Puts the popover's own content view on screen so its controls can be
    /// pressed. The popover itself can't open in tests: macOS doesn't place the
    /// test host's status item in the menu bar, so there is nothing to anchor to.
    private func showPopoverContent(of app: AppDelegate) throws -> NSView {
        let content = try XCTUnwrap(app.popover.contentViewController)
        let window = NSWindow(contentViewController: content)
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        addTeardownBlock { window.close() }
        return content.view
    }

    private func launchApp() -> (AppDelegate, DimmingController) {
        let controller = harness.makeController()
        let app = AppDelegate(controller: controller)
        app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        addTeardownBlock {
            app.popover.close()
            NSStatusBar.system.removeStatusItem(app.statusItem)
        }
        return (app, controller)
    }
}
