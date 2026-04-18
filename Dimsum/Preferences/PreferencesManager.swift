import Combine
import Foundation
import ServiceManagement

final class PreferencesManager: ObservableObject, PreferencesManaging {
    private let defaults: UserDefaults

    static let intensityKey = "dimsum.dimmingIntensity"
    static let enabledKey = "dimsum.isDimmingEnabled"
    static let loginKey = "dimsum.launchAtLogin"
    private static let hasLaunchedKey = "dimsum.hasLaunched"

    @Published var dimmingIntensity: Double {
        didSet {
            let clamped = dimmingIntensity.clamped(to: 0.1...0.8)
            if clamped != dimmingIntensity {
                dimmingIntensity = clamped
                return
            }
            defaults.set(clamped, forKey: Self.intensityKey)
        }
    }

    @Published var isDimmingEnabled: Bool {
        didSet {
            defaults.set(isDimmingEnabled, forKey: Self.enabledKey)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Self.loginKey)
            updateLoginItem(enabled: launchAtLogin)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if !defaults.bool(forKey: Self.hasLaunchedKey) {
            defaults.set(0.5, forKey: Self.intensityKey)
            defaults.set(true, forKey: Self.enabledKey)
            defaults.set(false, forKey: Self.loginKey)
            defaults.set(true, forKey: Self.hasLaunchedKey)
        }

        let raw = defaults.double(forKey: Self.intensityKey)
        self.dimmingIntensity = raw.clamped(to: 0.1...0.8)
        self.isDimmingEnabled = defaults.bool(forKey: Self.enabledKey)

        // Read persisted value without triggering SMAppService during init
        self.launchAtLogin = defaults.bool(forKey: Self.loginKey)
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Dimsum: Login item registration failed: \(error)")
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
