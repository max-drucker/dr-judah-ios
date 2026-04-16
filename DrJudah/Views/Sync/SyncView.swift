import SwiftUI

struct SyncView: View {
    @EnvironmentObject var syncManager: BackgroundSyncManager

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
                if syncManager.syncedVitalsCount > 0 || syncManager.syncedWorkoutsCount > 0 || syncManager.syncedSleepCount > 0 || syncManager.syncedMedicationsCount > 0 || syncManager.lastVitalsSync != nil || syncManager.lastWorkoutsSync != nil || syncManager.lastSleepSync != nil || syncManager.lastMedsSync != nil {
                    Section("Last Sync Results") {
                        syncResultRow(
                            icon: "heart.fill",
                            title: "Vitals",
                            count: syncManager.syncedVitalsCount,
                            lastSync: syncManager.lastVitalsSync,
                            color: .red
                        )
                        syncResultRow(
                            icon: "figure.run",
                            title: "Workouts",
                            count: syncManager.syncedWorkoutsCount,
                            lastSync: syncManager.lastWorkoutsSync,
                            color: .green
                        )
                        syncResultRow(
                            icon: "bed.double.fill",
                            title: "Sleep",
                            count: syncManager.syncedSleepCount,
                            lastSync: syncManager.lastSleepSync,
                            color: .indigo
                        )
                        syncResultRow(
                            icon: "pills.fill",
                            title: "Medications",
                            count: syncManager.syncedMedicationsCount,
                            lastSync: syncManager.lastMedsSync,
                            color: .blue
                        )
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
                    DataTypeRow(icon: "pills.fill", title: "Medications", color: .blue)
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
        }
    }

    @ViewBuilder
    private func syncResultRow(icon: String, title: String, count: Int, lastSync: Date?, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let lastSync {
                    Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Never")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        }
    }
}
