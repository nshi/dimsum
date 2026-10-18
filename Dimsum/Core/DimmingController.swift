import AppKit
import Combine

/// Runs dimming: waits for Accessibility permission, follows the preferences,
/// keeps overlays behind the focused window, and repairs them after system events.
final class DimmingController {
    typealias Schedule = (_ delay: TimeInterval, _ work: DispatchWorkItem) -> Void
    private typealias PendingWork = ReferenceWritableKeyPath<DimmingController, DispatchWorkItem?>

    /// Called when Accessibility permission is missing, at launch or mid-session.
    var onPermissionNeeded: (() -> Void)?
    /// Called once permission comes back, right before dimming restarts.
    var onPermissionGranted: (() -> Void)?

    let preferences: PreferencesManager
    private let overlayManager: OverlayManaging
    private let windowEnumerator: WindowEnumerating
    private let makeTracker: () -> WindowTracking
    private let isTrusted: () -> Bool
    private let frontmostPID: () -> pid_t?
    private let workspaceCenter: NotificationCenter
    private let appCenter: NotificationCenter
    private let schedule: Schedule

    // Non-nil exactly while dimming runs.
    private var tracker: WindowTracking?
    private var focusedWindowID: CGWindowID?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var appearanceObservation: NSKeyValueObservation?

    private var permissionCheck: DispatchWorkItem?
    private var spaceTransitionWork: DispatchWorkItem?
    private var reorderWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var intensityWork: DispatchWorkItem?
    private var appearanceWork: DispatchWorkItem?
    private var screenChangeWork: DispatchWorkItem?

    var isDimming: Bool { tracker != nil }

    init(
        preferences: PreferencesManager,
        overlayManager: OverlayManaging = OverlayManager(),
        windowEnumerator: WindowEnumerating = WindowEnumerator(),
        makeTracker: (() -> WindowTracking)? = nil,
        isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        frontmostPID: @escaping () -> pid_t? = {
            NSWorkspace.shared.frontmostApplication?.processIdentifier
        },
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        appCenter: NotificationCenter = .default,
        schedule: @escaping Schedule = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.preferences = preferences
        self.overlayManager = overlayManager
        self.windowEnumerator = windowEnumerator
        self.makeTracker = makeTracker ?? { WindowTracker(windowEnumerator: windowEnumerator) }
        self.isTrusted = isTrusted
        self.frontmostPID = frontmostPID
        self.workspaceCenter = workspaceCenter
        self.appCenter = appCenter
        self.schedule = schedule
    }

    deinit {
        shutdown()
    }

    // MARK: - Lifecycle

    func start() {
        if isTrusted() {
            enable()
        } else {
            requestPermission()
        }
    }

    func shutdown() {
        cancellables.removeAll()
        removeSystemObservers()
        stopDimming()
        for work: PendingWork in [\.permissionCheck, \.intensityWork] {
            cancel(work)
        }
    }

    private func enable() {
        if preferences.isDimmingEnabled {
            startDimming()
        }
        observePreferences()
        observeSystemEvents()
    }

    private func requestPermission() {
        onPermissionNeeded?()
        if permissionCheck == nil {
            schedulePermissionCheck()
        }
    }

    private func schedulePermissionCheck() {
        reschedule(\.permissionCheck, after: 1.0) { controller in
            guard controller.isTrusted() else {
                controller.schedulePermissionCheck()
                return
            }
            controller.onPermissionGranted?()
            controller.enable()
        }
    }

    private func startDimming() {
        stopDimming()

        // Assign state before starting: startTracking can report lost permission
        // synchronously, and that handler must be able to stop everything.
        let tracker = makeTracker()
        tracker.delegate = self
        self.tracker = tracker
        overlayManager.setupOverlays()
        do {
            try tracker.startTracking()
        } catch {
            NSLog("Dimsum: Failed to start window tracking: \(error)")
            stopDimming()
        }
    }

    private func stopDimming() {
        tracker?.stopTracking()
        tracker = nil
        focusedWindowID = nil
        for work: PendingWork in [\.reorderWork, \.retryWork] {
            cancel(work)
        }
        overlayManager.removeAllOverlays()
    }

    // MARK: - Overlay Placement

    private var currentIntensity: Double {
        adaptedIntensity(base: preferences.dimmingIntensity, isDarkMode: isDarkMode)
    }

    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func orderBehindFocusedWindow() {
        guard isDimming else { return }

        if let windowID = focusedWindowID {
            if frontmostAppHasFullScreenWindow() {
                overlayManager.hideAllOverlays()
                return
            }
            overlayManager.orderBehind(
                windowID: windowID,
                intensity: currentIntensity,
                animated: true
            )
        } else {
            overlayManager.hideAllOverlays()
        }
    }

    private func frontmostAppHasFullScreenWindow() -> Bool {
        guard let frontPID = frontmostPID() else { return false }
        let screenFrames = NSScreen.screens.map(\.frame)
        return windowEnumerator.visibleWindows().contains { window in
            window.ownerPID == frontPID && screenFrames.contains { frame in
                abs(window.bounds.width - frame.width) < 2
                    && window.bounds.height >= frame.height - 50
            }
        }
    }

    // MARK: - Observation

    private func observePreferences() {
        cancellables.removeAll()

        preferences.dimmingIntensityDidChange
            .sink { [weak self] _ in
                self?.reschedule(\.intensityWork, after: 0.05) { controller in
                    guard controller.isDimming else { return }
                    controller.overlayManager.updateIntensity(controller.currentIntensity, animated: false)
                }
            }
            .store(in: &cancellables)

        preferences.isDimmingEnabledDidChange
            .sink { [weak self] enabled in
                if enabled {
                    self?.startDimming()
                } else {
                    self?.stopDimming()
                }
            }
            .store(in: &cancellables)
    }

    private func observeSystemEvents() {
        removeSystemObservers()

        observe(workspaceCenter, NSWorkspace.activeSpaceDidChangeNotification) { controller in
            controller.reschedule(\.spaceTransitionWork, after: 0.3) { controller in
                // Forget the old window so the same one re-orders on the new Space.
                // If nothing is focused there, the lookup reports nil again, which
                // isn't a change, so hide here.
                controller.focusedWindowID = nil
                controller.tracker?.refreshFocusedWindow()
                if controller.focusedWindowID == nil {
                    controller.overlayManager.hideAllOverlays()
                }
            }
        }

        // Wake and screen-parameter changes arrive together; rebuild once per burst.
        let rebuildOverlays = { (controller: DimmingController) in
            controller.reschedule(\.screenChangeWork, after: 0) { controller in
                guard controller.isDimming else { return }
                controller.overlayManager.rebuildOverlays()
                controller.orderBehindFocusedWindow()
            }
        }
        observe(appCenter, NSApplication.didChangeScreenParametersNotification, rebuildOverlays)
        // Overlays can be torn down while displays are off during sleep, and no
        // screen-parameter change is guaranteed once they come back.
        observe(workspaceCenter, NSWorkspace.screensDidWakeNotification, rebuildOverlays)

        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            self?.reschedule(\.appearanceWork, after: 0.1) { controller in
                guard controller.isDimming else { return }
                controller.overlayManager.updateIntensity(controller.currentIntensity, animated: true)
            }
        }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ handler: @escaping (DimmingController) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if let self { handler(self) }
        }
        observers.append((center, token))
    }

    private func removeSystemObservers() {
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        appearanceObservation?.invalidate()
        appearanceObservation = nil
        for work: PendingWork in [\.spaceTransitionWork, \.appearanceWork, \.screenChangeWork] {
            cancel(work)
        }
    }

    // MARK: - Delayed Work

    /// Replaces any pending work in `slot` with `body`, run after `delay`.
    private func reschedule(
        _ slot: PendingWork,
        after delay: TimeInterval,
        _ body: @escaping (DimmingController) -> Void
    ) {
        self[keyPath: slot]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self[keyPath: slot] = nil
            body(self)
        }
        self[keyPath: slot] = work
        schedule(delay, work)
    }

    private func cancel(_ slot: PendingWork) {
        self[keyPath: slot]?.cancel()
        self[keyPath: slot] = nil
    }
}

// MARK: - WindowTrackerDelegate

extension DimmingController: WindowTrackerDelegate {
    func accessibilityPermissionLost() {
        stopDimming()
        requestPermission()
    }

    func focusedWindowDidChange(to windowID: CGWindowID?) {
        guard windowID != focusedWindowID else { return }
        focusedWindowID = windowID
        // A Space change in progress resolves focus again once it settles.
        guard spaceTransitionWork == nil else { return }

        if let windowID {
            orderBehindFocusedWindow()
            // Re-order after the window server finishes its activation animation,
            // ensuring the overlay lands directly behind the focused window.
            cancel(\.retryWork)
            reschedule(\.reorderWork, after: 0.15) { controller in
                guard controller.focusedWindowID == windowID else { return }
                controller.orderBehindFocusedWindow()
            }
        } else {
            // Window may not be in CG list yet; retry, then hide if still unresolved.
            cancel(\.reorderWork)
            reschedule(\.retryWork, after: 0.5) { controller in
                guard controller.focusedWindowID == nil else { return }
                controller.tracker?.refreshFocusedWindow()
                if controller.focusedWindowID == nil {
                    controller.overlayManager.hideAllOverlays()
                }
            }
        }
    }
}
