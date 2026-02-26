import SwiftUI

struct DNAView: View {
    @StateObject private var api = APIManager.shared

    private var dnaItems: [(String, String)] {
        guard let metrics = api.currentState?.healthMetrics else { return [] }
        // Filter for DNA/genetics related metrics
        return metrics.compactMap { key, metric in
            guard key.lowercased().contains("dna") || key.lowercased().contains("gene") || key.lowercased().contains("genetic") else { return nil }
            return (key, metric.summary ?? metric.detail ?? metric.status ?? "–")
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if api.isLoadingState {
                    ProgressView("Loading DNA data…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if dnaItems.isEmpty {
                    // Show general genetics info from recommendations
                    VStack(spacing: 16) {
                        Image(systemName: "dna")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("DNA & Genetics")
                            .font(.title2.bold())

                        Text("Genetic insights from your DNA analysis are integrated throughout your health recommendations. Key findings include MTHFR, VDR, and FADS1 variants.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Show DNA-related recommendations
                        let dnaRecs = AppRecommendation.allRecommendations.filter {
                            $0.title.lowercased().contains("gene") || $0.title.lowercased().contains("dna") || $0.category == "Supplements"
                        }
                        ForEach(dnaRecs) { rec in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: rec.icon)
                                        .foregroundStyle(.green)
                                    Text(rec.title)
                                        .font(.subheadline.bold())
                                }
                                Text(rec.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(dnaItems, id: \.0) { key, value in
                        HStack {
                            Image(systemName: "dna")
                                .foregroundStyle(.green)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key)
                                    .font(.subheadline.bold())
                                Text(value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("DNA & Genetics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.fetchCurrentState() }
        .refreshable { await api.fetchCurrentState(force: true) }
    }
}
