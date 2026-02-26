import SwiftUI

struct SleepView: View {
    @StateObject private var api = APIManager.shared

    private var sleepVitals: [(String, String)] {
        guard let vitals = api.currentState?.vitals else { return [] }
        return vitals.compactMap { key, val in
            guard key.lowercased().contains("sleep") else { return nil }
            let display = val.stringValue ?? val.doubleValue.map { String(format: "%.1f", $0) } ?? "–"
            return (formatKey(key), display)
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if api.isLoadingState {
                    ProgressView("Loading sleep data…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if sleepVitals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.indigo)

                        Text("Sleep Analysis")
                            .font(.title2.bold())

                        Text("Sleep data from Apple Health is synced automatically. Check back after your HealthKit sync to see sleep scores, duration, and trends.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(sleepVitals, id: \.0) { key, value in
                        HStack {
                            Image(systemName: "bed.double.fill")
                                .foregroundStyle(.indigo)
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
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task { await api.fetchCurrentState() }
        .refreshable { await api.fetchCurrentState(force: true) }
    }

    private func formatKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
