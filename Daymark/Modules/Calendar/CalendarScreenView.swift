import SwiftUI

struct CalendarScreenView: View {
    @Bindable var viewModel: MainScreenViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Included calendars") {
                    if viewModel.authorizationState == .fullAccess {
                        if viewModel.calendars.isEmpty {
                            ContentUnavailableView(
                                "No Calendars",
                                systemImage: "calendar.badge.exclamationmark",
                                description: Text("No visible non-birthday calendars are available.")
                            )
                            Button("Refresh") {
                                Task {
                                    await viewModel.load()
                                }
                            }
                        } else {
                            ForEach(viewModel.calendars) { calendar in
                                Toggle(calendar.title, isOn: $viewModel[calendar: calendar.id])
                            }
                        }
                    } else {
                        Text("Grant full calendar access in the Status tab to choose calendars.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Working hours") {
                    DatePicker(
                        "Start",
                        selection: $viewModel.workingDayStartsAt,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End",
                        selection: $viewModel.workingDayEndsAt,
                        displayedComponents: .hourAndMinute
                    )

                    if viewModel.workingDayStartsAt >= viewModel.workingDayEndsAt {
                        Text("End time must be later than start time.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Demo schedule") {
                    Button("Create Demo Schedule", systemImage: "calendar.badge.plus") {
                        Task {
                            await viewModel.createDemoSchedule()
                        }
                    }
                    .disabled(viewModel.authorizationState != .fullAccess || viewModel.isLoading)

                    Button("Remove Demo Schedule", systemImage: "calendar.badge.minus", role: .destructive) {
                        Task {
                            await viewModel.removeDemoSchedule()
                        }
                    }
                    .disabled(viewModel.authorizationState != .fullAccess || viewModel.isLoading)

                    if let demoStatus = viewModel.demoStatus {
                        Text(demoStatus)
                            .foregroundStyle(.secondary)
                    }

                    Text("Only events marked \"Demo -\" and owned by Daymark are removed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Calendar")
            .refreshable {
                await viewModel.load()
            }
        }
    }
}
