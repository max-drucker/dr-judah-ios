import SwiftUI

struct ImagingView: View {
    @EnvironmentObject var apiManager: APIManager

    private var imagingData: [(String, String)] {
        guard let state = apiManager.currentState else { return [] }
        var items: [(String, String)] = []

        // Extract DXA data
        if let dxa = state.dxa {
            for (key, val) in dxa.sorted(by: { $0.key < $1.key }) {
                let display = val.stringValue ?? val.doubleValue.map { String(format: "%.1f", $0) } ?? "–"
                items.append((formatKey(key), display))
            }
        }

        return items
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if apiManager.isLoadingState {
                    ProgressView("Loading imaging data…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if imagingData.isEmpty {
                    ContentUnavailableView("No Imaging Data", systemImage: "photo.stack", description: Text("DXA scans, MRIs, and other imaging will appear here."))
                } else {
                    // DXA Section
                    if apiManager.currentState?.dxa != nil {
                        sectionHeader("DXA Body Composition")
                    }

                    ForEach(imagingData, id: \.0) { key, value in
                        HStack {
                            Text(key)
                                .font(.subheadline)
                            Spacer()
                            Text(value)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.drJudahBlue)
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
        .navigationTitle("Imaging & Scans")
        .navigationBarTitleDisplayMode(.inline)
        .task { await apiManager.fetchCurrentState() }
        .refreshable { await apiManager.fetchCurrentState(force: true) }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private func formatKey(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
