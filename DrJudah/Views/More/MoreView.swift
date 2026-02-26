import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {
    @EnvironmentObject var syncManager: BackgroundSyncManager

    @State private var showWebSheet = false
    @State private var webURL: URL?
    @State private var showOmronImporter = false
    @State private var omronImportResult: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                // Sync Status
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Sync")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let date = syncManager.lastSyncDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                            } else {
                                Text("Never — will sync 2 years of data")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await syncManager.performSync() }
                        } label: {
                            if syncManager.isSyncing {
                                ProgressView()
                            } else {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "3B82F6"))
                        .disabled(syncManager.isSyncing)
                    }
                    .padding(.vertical, 4)

                    if syncManager.isSyncing && !syncManager.syncProgress.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(syncManager.syncProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("HealthKit Sync")
                }

                // Last Sync Results
                if syncManager.syncedVitalsCount > 0 || syncManager.syncedWorkoutsCount > 0 || syncManager.syncedSleepCount > 0 {
                    Section("Last Sync Results") {
                        DataTypeRow(icon: "heart.fill", title: "Vitals", count: syncManager.syncedVitalsCount, color: .red)
                        DataTypeRow(icon: "figure.run", title: "Workouts", count: syncManager.syncedWorkoutsCount, color: .green)
                        DataTypeRow(icon: "bed.double.fill", title: "Sleep", count: syncManager.syncedSleepCount, color: .indigo)
                    }
                }

                if let error = syncManager.syncError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Quick Links to Web App
                Section("Health Data") {
                    nativeLink(icon: "flask.fill", title: "Labs & Bloodwork", color: .blue) { LabsView() }
                    nativeLink(icon: "bed.double.fill", title: "Sleep Analysis", color: .indigo) { SleepView() }
                    nativeLink(icon: "photo.stack", title: "Imaging & Scans", color: .purple) { ImagingView() }
                    nativeLink(icon: "dna", title: "DNA & Genetics", color: .green) { DNAView() }
                    nativeLink(icon: "pill.fill", title: "Supplements", color: .orange) { SupplementsView() }
                    nativeLink(icon: "cross.vial.fill", title: "Medications", color: .red) { MedicationsView() }
                    nativeLink(icon: "calendar.badge.clock", title: "Screening Schedule", color: .teal) { ScreeningsView() }
                }

                // Omron CSV Import
                Section {
                    Button {
                        showOmronImporter = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "3B82F6"))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Omron BP Data")
                                    .font(.subheadline.bold())
                                Text("Upload a CSV export from Omron Connect")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isImporting)

                    if isImporting {
                        HStack {
                            ProgressView()
                            Text("Importing…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let result = omronImportResult {
                        HStack {
                            Image(systemName: result.contains("Error") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(result.contains("Error") ? .orange : .green)
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Blood Pressure Import")
                } footer: {
                    Text("Omron Connect → Export → CSV. Import blood pressure readings as a backup to HealthKit sync.")
                }

                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("User")
                        Spacer()
                        Text(Config.userEmail)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dr. Judah syncs your health data to provide personalized AI insights. Data is securely stored and only accessible to you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("More")
            .sheet(isPresented: $showWebSheet) {
                if let url = webURL {
                    WebViewSheet(url: url)
                }
            }
            .fileImporter(
                isPresented: $showOmronImporter,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleOmronImport(result: result)
            }
        }
    }

    // MARK: - Native Link Row

    private func nativeLink<Destination: View>(icon: String, title: String, color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Web Link Row

    private func webLink(icon: String, title: String, color: Color, path: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            webURL = URL(string: Config.apiBaseURL + path)
            showWebSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "safari")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Omron Import

    private func handleOmronImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            omronImportResult = nil

            Task {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        omronImportResult = "Error: Could not access file."
                        isImporting = false
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let csvString = try String(contentsOf: url, encoding: .utf8)
                    let readings = try OmronCSVImporter.parse(csvString: csvString)
                    try await OmronCSVImporter.upload(readings)
                    omronImportResult = "✓ Imported \(readings.count) blood pressure readings"
                } catch {
                    omronImportResult = "Error: \(error.localizedDescription)"
                }
                isImporting = false
            }

        case .failure(let error):
            omronImportResult = "Error: \(error.localizedDescription)"
        }
    }
}
