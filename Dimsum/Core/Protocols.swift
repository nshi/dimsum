import AppKit
import CoreGraphics

protocol WindowTrackerDelegate: AnyObject {
    func focusedWindowDidChange(to windowID: CGWindowID?)
}

protocol WindowTracking {
    var delegate: WindowTrackerDelegate? { get set }
    func startTracking() throws
    func stopTracking()
    func refreshFocusedWindow()
}

protocol OverlayManaging {
    func setupOverlays()
    func orderBehind(windowID: CGWindowID, intensity: Double, animated: Bool)
    func updateIntensity(_ intensity: Double, animated: Bool)
    func hideAllOverlays()
    func removeAllOverlays()
    func rebuildOverlays()
}

protocol WindowEnumerating {
    func visibleWindows() -> [WindowInfo]
}

protocol PreferencesManaging {
    var dimmingIntensity: Double { get set }
    var isDimmingEnabled: Bool { get set }
    var launchAtLogin: Bool { get set }
}
