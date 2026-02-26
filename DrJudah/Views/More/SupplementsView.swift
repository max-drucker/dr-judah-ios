import SwiftUI

struct SupplementsView: View {
    @StateObject private var api = APIManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if api.isLoadingState {
                    ProgressView("Loading supplements…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let supplements = api.currentState?.supplements, !supplements.isEmpty {
                    ForEach(supplements) { supp in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pill.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(supp.name)
                                    .font(.subheadline.bold())
                                if let dose = supp.dose {
                                    Text(dose)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let freq = supp.frequency {
                                    Text(freq)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let reason = supp.reason {
                                    Text(reason)
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
                    ContentUnavailableView("No Supplements", systemImage: "pill.fill", description: Text("Your supplement stack will appear here."))
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Supplements")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.fetchCurrentState() }
        .refreshable { await api.fetchCurrentState(force: true) }
    }
}
