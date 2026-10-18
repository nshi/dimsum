import SwiftUI

struct QuitButton: View {
    var body: some View {
        Button("Quit Dimsum") {
            NSApplication.shared.terminate(nil)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
