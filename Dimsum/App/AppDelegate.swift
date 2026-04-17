import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let preferences = PreferencesManager()
    private var windowTracker: WindowTracker?
    private let windowEnumerator = WindowEnumerator()
    private let overlayManager = OverlayManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentFocusedWindowID: CGWindowID?
    private var accessibilityCheckTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var defaultObservers: [NSObjectProtocol] = []
    private var isTransitioningSpaces = false
    private var spaceTransitionWork: DispatchWorkItem?
    private var reorderWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        if AXIsProcessTrusted() {
            enableDimming()
        } else {
            showPermissionView()
            startAccessibilityPolling()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityCheckTimer?.invalidate()
        stopDimming()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "circle.lefthalf.filled",
                accessibilityDescription: "Dimsum"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(preferences: preferences)
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

    private func startAccessibilityPolling() {
        accessibilityCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard AXIsProcessTrusted() else { return }
            self?.accessibilityCheckTimer?.invalidate()
            self?.accessibilityCheckTimer = nil
            self?.popover.performClose(nil)
            self?.setupPopover()
            self?.enableDimming()
        }
    }

    // MARK: - Dimming Lifecycle

    private func enableDimming() {
        startDimming()
        observePreferences()
        observeSystemEvents()
    }

    private func startDimming() {
        guard preferences.isDimmingEnabled else { return }
        stopDimming()

        do {
            let tracker = WindowTracker(windowEnumerator: windowEnumerator)
            tracker.delegate = self
            try tracker.startTracking()
            windowTracker = tracker
            overlayManager.setupOverlays()
        } catch {
            NSLog("Dimsum: Failed to start window tracking: \(error)")
        }
    }

    private func stopDimming() {
        windowTracker?.stopTracking()
        windowTracker = nil
        overlayManager.removeAllOverlays()
    }

    private func orderBehindFocusedWindow() {
        guard preferences.isDimmingEnabled else { return }

        if let windowID = currentFocusedWindowID {
            let windows = windowEnumerator.visibleWindows()
            if frontmostAppHasFullScreenWindow(in: windows) {
                overlayManager.hideAllOverlays()
                return
            }
            overlayManager.orderBehind(
                windowID: windowID,
                intensity: preferences.dimmingIntensity,
                animated: true
            )
        } else {
            overlayManager.hideAllOverlays()
        }
    }

    private func frontmostAppHasFullScreenWindow(in windows: [WindowInfo]) -> Bool {
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return false
        }
        return windows.contains { $0.ownerPID == frontPID && isFullScreen($0) }
    }

    private func isFullScreen(_ window: WindowInfo) -> Bool {
        for screen in NSScreen.screens {
            if abs(window.bounds.width - screen.frame.width) < 2
                && window.bounds.height >= screen.frame.height - 50 {
                return true
            }
        }
        return false
    }

    // MARK: - Preference Observation

    private func observePreferences() {
        preferences.$dimmingIntensity
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.overlayManager.updateIntensity(newValue, animated: false)
            }
            .store(in: &cancellables)

        preferences.$isDimmingEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.startDimming()
                    self.orderBehindFocusedWindow()
                } else {
                    self.stopDimming()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - System Events

    private func observeSystemEvents() {
        removeSystemEventObservers()

        let spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.spaceTransitionWork?.cancel()
            self.isTransitioningSpaces = true
            self.overlayManager.hideAllOverlays()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isTransitioningSpaces = false
                self.currentFocusedWindowID = nil
                self.windowTracker?.refreshFocusedWindow()
            }
            self.spaceTransitionWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }

        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.overlayManager.rebuildOverlays()
            self.orderBehindFocusedWindow()
        }

        workspaceObservers = [spaceObserver]
        defaultObservers = [screenObserver]
    }

    private func removeSystemEventObservers() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        for observer in defaultObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        defaultObservers.removeAll()
    }
}

// MARK: - WindowTrackerDelegate

extension AppDelegate: WindowTrackerDelegate {
    func focusedWindowDidChange(to windowID: CGWindowID?) {
        guard windowID != currentFocusedWindowID else { return }
        currentFocusedWindowID = windowID
        guard !isTransitioningSpaces else { return }
        orderBehindFocusedWindow()

        reorderWork?.cancel()
        retryWork?.cancel()
        if let windowID {
            // Re-order after the window server finishes its activation animation,
            // ensuring the overlay lands directly behind the focused window.
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.currentFocusedWindowID == windowID else { return }
                self.orderBehindFocusedWindow()
            }
            reorderWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        } else {
            // Window ID resolution can fail during Mission Control transitions.
            // Retry after animation settles.
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.currentFocusedWindowID == nil else { return }
                self.windowTracker?.refreshFocusedWindow()
            }
            retryWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }
}
