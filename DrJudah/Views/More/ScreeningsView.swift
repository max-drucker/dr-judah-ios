import SwiftUI

struct ScreeningsView: View {
    @StateObject private var api = APIManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if api.isLoadingState {
                    ProgressView("Loading screenings…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let screenings = api.currentState?.screenings, !screenings.isEmpty {
                    ForEach(screenings) { screening in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: statusIcon(screening.status))
                                .font(.title3)
                                .foregroundStyle(statusColor(screening.status))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(screening.name)
                                    .font(.subheadline.bold())

                                if let status = screening.status {
                                    Text(status.capitalized)
                                        .font(.caption.bold())
                                        .foregroundStyle(statusColor(status))
                                }

                                if let lastDate = screening.lastDate {
                                    Text("Last: \(lastDate)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let nextDue = screening.nextDue {
                                    Text("Next due: \(nextDue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let notes = screening.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                } else {
                    ContentUnavailableView("No Screenings", systemImage: "calendar.badge.clock", description: Text("Your screening schedule will appear here."))
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Screening Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.fetchCurrentState() }
        .refreshable { await api.fetchCurrentState(force: true) }
    }

    private func statusIcon(_ status: String?) -> String {
        switch status?.lowercased() {
        case "overdue": return "exclamationmark.triangle.fill"
        case "upcoming": return "clock.fill"
        case "current": return "checkmark.circle.fill"
        default: return "calendar.badge.clock"
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "overdue": return .red
        case "upcoming": return .orange
        case "current": return .green
        default: return .teal
        }
    }
}
