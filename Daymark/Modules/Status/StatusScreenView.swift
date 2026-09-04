import SwiftUI

struct StatusScreenView: View {
    let viewModel: MainScreenViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("App", value: viewModel.status)
                    LabeledContent("Foundation Models") {
                        Text(viewModel.modelAvailabilityDescription)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Calendar") {
                        Text(viewModel.authorizationDescription)
                            .multilineTextAlignment(.trailing)
                    }

                    if viewModel.canRequestCalendarAccess {
                        Button("Grant Calendar Access", systemImage: "calendar.badge.checkmark") {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Status")
            .refreshable {
                await viewModel.load()
            }
        }
    }
}
