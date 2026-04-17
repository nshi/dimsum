import SwiftUI

struct PopoverView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dimsum")
                    .font(.headline)
                Spacer()
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Toggle("Enable Dimming", isOn: $preferences.isDimmingEnabled)
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 4) {
                Text("Dimming Intensity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Slider(value: $preferences.dimmingIntensity, in: 0.1...0.8)
                    Image(systemName: "moon.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .opacity(preferences.isDimmingEnabled ? 1.0 : 0.5)
            .disabled(!preferences.isDimmingEnabled)

            Toggle("Start on Login", isOn: $preferences.launchAtLogin)
                .toggleStyle(.switch)

            Divider()

            Button("Quit Dimsum") {
                NSApplication.shared.terminate(nil)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 280)
    }
}
