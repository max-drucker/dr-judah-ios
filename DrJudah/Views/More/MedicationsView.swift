import SwiftUI

struct MedicationsView: View {
    @EnvironmentObject var apiManager: APIManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if apiManager.isLoadingState {
                    ProgressView("Loading medications…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let meds = apiManager.currentState?.meds, !meds.isEmpty {
                    ForEach(meds) { med in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cross.vial.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(med.name)
                                    .font(.subheadline.bold())
                                if let dose = med.dose {
                                    Text(dose)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let freq = med.frequency {
                                    Text(freq)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let purpose = med.purpose {
                                    Text(purpose)
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
                    ContentUnavailableView("No Medications", systemImage: "cross.vial.fill", description: Text("Your medications will appear here."))
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await apiManager.fetchCurrentState() }
        .refreshable { await apiManager.fetchCurrentState(force: true) }
    }
}
