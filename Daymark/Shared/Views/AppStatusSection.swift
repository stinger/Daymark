import SwiftUI

struct AppStatusSection: View {
    let status: String

    var body: some View {
        Section("App") {
            Label(status, systemImage: "app")
        }
    }
}
