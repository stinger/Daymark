import SwiftUI

struct StatusScreenView: View {
    let viewModel: MainScreenViewModel

    var body: some View {
        NavigationStack {
            List {
                AppStatusSection(status: viewModel.status)
                FoundationModelsStatusSection(description: viewModel.modelAvailabilityDescription)
                CalendarStatusSection(
                    description: viewModel.authorizationDescription,
                    canRequestAccess: viewModel.canRequestCalendarAccess,
                    isLoading: viewModel.isLoading,
                    requestAccess: viewModel.requestCalendarAccess
                )

                if let errorMessage = viewModel.errorMessage {
                    StatusErrorSection(message: errorMessage)
                }
            }
            .navigationTitle("Status")
            .refreshable {
                await viewModel.load()
            }
        }
    }
}
