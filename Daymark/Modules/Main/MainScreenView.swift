import SwiftUI

struct MainScreenView: View {
    @State private var viewModel = MainScreenViewModel()

    var body: some View {
        TabView {
            Tab("Assistant", systemImage: "sparkles") {
                AssistantScreenView(viewModel: viewModel)
            }

            Tab("Calendar", systemImage: "calendar") {
                CalendarScreenView(viewModel: viewModel)
            }

            Tab("Status", systemImage: "checkmark.circle") {
                StatusScreenView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading && viewModel.calendars.isEmpty {
                ProgressView()
            }
        }
    }
}
