import AppKit
import XCTest
@testable import Dimsum

final class PermissionViewTests: XCTestCase {
    func testPermissionViewHasQuitButton() {
        let (window, root) = hostOnScreen(PermissionView())
        addTeardownBlock { window.close() }

        let quit = findAccessibilityElement(under: root) {
            $0.accessibilityRole?() == .button && accessibilityLabel(of: $0) == "Quit Dimsum"
        }
        XCTAssertNotNil(quit)
    }
}
