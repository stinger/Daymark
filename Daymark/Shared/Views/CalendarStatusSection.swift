import SwiftUI

struct CalendarStatusSection: View {
    let description: String
    let canRequestAccess: Bool
    let isLoading: Bool
    let requestAccess: () async -> Void

    var body: some View {
        Section("Calendar") {
            Label(description, systemImage: "calendar")

            if canRequestAccess {
                Button("Grant Calendar Access", systemImage: "calendar.badge.checkmark") {
                    Task {
                        await requestAccess()
                    }
                }
                .disabled(isLoading)
            }
        }
    }
}
