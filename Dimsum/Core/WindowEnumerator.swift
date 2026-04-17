import CoreGraphics
import Foundation

final class WindowEnumerator: WindowEnumerating {
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func visibleWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else {
            return []
        }

        return windowList.compactMap { dict in
            parseWindowInfo(from: dict)
        }
    }

    func parseWindowInfo(from dict: [CFString: Any]) -> WindowInfo? {
        guard
            let windowID = dict[kCGWindowNumber] as? CGWindowID,
            let ownerPID = dict[kCGWindowOwnerPID] as? pid_t,
            let layer = dict[kCGWindowLayer] as? Int,
            layer == 0,
            ownerPID != ownPID
        else {
            return nil
        }

        let ownerName = dict[kCGWindowOwnerName] as? String ?? ""

        guard let boundsDict = dict[kCGWindowBounds] as? [String: CGFloat],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            return nil
        }

        let alpha = dict[kCGWindowAlpha] as? CGFloat ?? 1.0
        let isOnScreen = (dict[kCGWindowIsOnscreen] as? Bool) ?? true

        return WindowInfo(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            bounds: bounds,
            layer: layer,
            alpha: alpha,
            isOnScreen: isOnScreen
        )
    }
}
