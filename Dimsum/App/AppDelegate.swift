import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem!
    let popover = NSPopover()
    private let controller: DimmingController
    private var isTestHost = false

    override convenience init() {
        self.init(controller: DimmingController(preferences: PreferencesManager()))
        // Unit tests run inside this app. Keep its own instance idle so it can't
        // dim or reorder windows underneath them.
        isTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init(controller: DimmingController) {
        self.controller = controller
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTestHost else { return }
        setupStatusItem()
        setupPopover()

        controller.onPermissionNeeded = { [weak self] in
            self?.showPermissionView()
        }
        controller.onPermissionGranted = { [weak self] in
            self?.popover.performClose(nil)
            self?.setupPopover()
        }
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(preferences: controller.preferences)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showPermissionView() {
        popover.contentViewController = NSHostingController(
            rootView: PermissionView()
        )
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
