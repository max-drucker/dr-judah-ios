import SwiftUI
import Charts

struct LabsView: View {
    @EnvironmentObject var apiManager: APIManager
    @State private var searchText = ""
    @State private var selectedBiomarker: String?

    private let keyBiomarkers = [
        "LDL Cholesterol", "HDL Cholesterol", "HbA1c", "ALT", "hs-CRP",
        "Free Testosterone", "SHBG", "Glucose", "Triglycerides",
        "Total Cholesterol", "ApoB", "Insulin"
    ]

    private var filteredStats: [(String, [LabDataPoint])] {
        let stats = apiManager.labStats
        let filtered: [(String, [LabDataPoint])]
        if searchText.isEmpty {
            filtered = stats.sorted { $0.key < $1.key }
        } else {
            filtered = stats.filter { $0.key.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.key < $1.key }
        }
        return filtered
    }

    private var keyBiomarkerData: [(String, [LabDataPoint])] {
        keyBiomarkers.compactMap { name in
            if let data = apiManager.labStats[name], !data.isEmpty {
                return (name, data)
            }
            return nil
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if apiManager.isLoadingLabs {
                    ProgressView("Loading labs…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if apiManager.labStats.isEmpty {
                    ContentUnavailableView("No Lab Data", systemImage: "flask.fill", description: Text("Lab results will appear here once synced."))
                } else {
                    // Key biomarkers grid
                    if !keyBiomarkerData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Biomarkers")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(keyBiomarkerData, id: \.0) { name, data in
                                    BiomarkerCard(name: name, data: data)
                                        .onTapGesture { selectedBiomarker = name }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search biomarkers…", text: $searchText)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // All results
                    ForEach(filteredStats, id: \.0) { name, data in
                        LabRowCard(name: name, data: data)
                            .onTapGesture { selectedBiomarker = name }
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Labs & Bloodwork")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await apiManager.fetchLabStats()
        }
        .refreshable {
            await apiManager.fetchLabStats(force: true)
        }
        .sheet(item: Binding(
            get: { selectedBiomarker.map { SelectedBiomarker(name: $0) } },
            set: { selectedBiomarker = $0?.name }
        )) { selected in
            BiomarkerDetailSheet(name: selected.name, data: apiManager.labStats[selected.name] ?? [])
        }
    }
}

private struct SelectedBiomarker: Identifiable {
    let name: String
    var id: String { name }
}

private struct BiomarkerCard: View {
    let name: String
    let data: [LabDataPoint]

    var body: some View {
        let latest = data.last
        let prev = data.count > 1 ? data[data.count - 2] : nil
        let change: Double? = {
            guard let l = latest, let p = prev, p.value != 0 else { return nil }
            return (l.value - p.value) / p.value * 100
        }()

        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(latest.map { formatValue($0.value) } ?? "–")
                    .font(.title2.bold())
                    .foregroundStyle(Color.drJudahBlue)

                if let change {
                    HStack(spacing: 1) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(change), specifier: "%.0f")%")
                    }
                    .font(.caption2)
                    .foregroundStyle(change > 0 ? .red : .green)
                }
            }

            if data.count > 1 {
                Chart(data, id: \.id) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(Color.drJudahBlue)
                    AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(Color.drJudahBlue.opacity(0.1))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 40)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct LabRowCard: View {
    let name: String
    let data: [LabDataPoint]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.bold())
                Text("\(data.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let latest = data.last {
                Text(formatValue(latest.value))
                    .font(.headline)
                    .foregroundStyle(Color.drJudahBlue)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct BiomarkerDetailSheet: View {
    let name: String
    let data: [LabDataPoint]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if data.count > 1 {
                        Chart(data, id: \.id) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                                .foregroundStyle(Color.drJudahBlue)
                            PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                                .foregroundStyle(Color.drJudahBlue)
                        }
                        .frame(height: 200)
                        .padding()
                    }

                    ForEach(data.reversed(), id: \.id) { point in
                        HStack {
                            Text(point.date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatValue(point.value))
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private func formatValue(_ value: Double) -> String {
    value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
}
