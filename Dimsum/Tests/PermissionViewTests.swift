import AppKit
import SwiftUI
import XCTest
@testable import Dimsum

final class PermissionViewTests: XCTestCase {
    func testPermissionViewHasQuitButton() {
        let hostingView = NSHostingView(rootView: PermissionView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        addTeardownBlock { window.close() }

        let labels = buttonLabels(in: hostingView)
        XCTAssertTrue(labels.contains("Quit Dimsum"), "Buttons found: \(labels)")
    }

    // SwiftUI's accessibility nodes are private types, so query them through dynamic lookup.
    private func buttonLabels(in element: AnyObject) -> [String] {
        var labels: [String] = []
        if element.accessibilityRole?() == .button {
            labels.append(element.accessibilityLabel?() ?? element.accessibilityTitle?() ?? "")
        }
        for child in element.accessibilityChildren?() ?? [] {
            labels += buttonLabels(in: child as AnyObject)
        }
        return labels
    }
}
