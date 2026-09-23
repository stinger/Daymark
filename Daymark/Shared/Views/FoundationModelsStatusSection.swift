import SwiftUI

struct FoundationModelsStatusSection: View {
    let description: String

    var body: some View {
        Section("Foundation Models") {
            Label(description, systemImage: "apple.intelligence")
        }
    }
}
