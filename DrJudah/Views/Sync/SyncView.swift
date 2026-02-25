import SwiftUI
import UniformTypeIdentifiers

struct SyncView: View {
    @EnvironmentObject var syncManager: BackgroundSyncManager

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
                        .tint(Color(red: 0.145, green: 0.388, blue: 0.922))
                        .disabled(syncManager.isSyncing)
                    }
                    .padding(.vertical, 4)

                    if syncManager.isSyncing && !syncManager.syncProgress.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(syncManager.syncProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                // Data Types
                Section("Synced Data Types") {
                    DataTypeRow(icon: "heart.fill", title: "Heart Rate", color: .red)
                    DataTypeRow(icon: "waveform.path.ecg", title: "HRV", color: .purple)
                    DataTypeRow(icon: "figure.walk", title: "Steps", color: .green)
                    DataTypeRow(icon: "flame.fill", title: "Active Calories", color: .orange)
                    DataTypeRow(icon: "figure.run", title: "Exercise Minutes", color: .cyan)
                    DataTypeRow(icon: "lungs.fill", title: "Blood Oxygen", color: .blue)
                    DataTypeRow(icon: "drop.fill", title: "Blood Glucose (CGM)", color: .orange)
                    DataTypeRow(icon: "heart.circle.fill", title: "Blood Pressure", color: .red)
                    DataTypeRow(icon: "percent", title: "Body Fat", color: .purple)
                    DataTypeRow(icon: "figure.strengthtraining.traditional", title: "Lean Body Mass", color: .green)
                    DataTypeRow(icon: "bone", title: "Bone Mineral Density", color: .gray)
                    DataTypeRow(icon: "wind", title: "VO₂ Max", color: .teal)
                    DataTypeRow(icon: "lungs", title: "Respiratory Rate", color: .blue)
                    DataTypeRow(icon: "bed.double.fill", title: "Sleep", color: .indigo)
                    DataTypeRow(icon: "dumbbell.fill", title: "Workouts", color: .green)
                    DataTypeRow(icon: "scalemass.fill", title: "Body Mass", color: .gray)
                }

                // Omron CSV Import
                Section {
                    Button {
                        showOmronImporter = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.145, green: 0.388, blue: 0.922))

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

                // Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dr. Judah syncs your health data to provide personalized AI insights. Data is securely stored and only accessible to you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("User: \(Config.userEmail)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Sync & Settings")
            .fileImporter(
                isPresented: $showOmronImporter,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleOmronImport(result: result)
            }
        }
    }

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
