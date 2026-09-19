import SwiftUI

struct StatusErrorSection: View {
    let message: String

    var body: some View {
        Section("Error") {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}
