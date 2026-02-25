import SwiftUI

struct SyncView: View {
    @EnvironmentObject var syncManager: BackgroundSyncManager
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            List {
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
                                Text("Never")
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
                        .tint(.drJudahBlue)
                        .disabled(syncManager.isSyncing)
                    }
                    .padding(.vertical, 4)
                }

                if syncManager.syncedVitalsCount > 0 || syncManager.syncedWorkoutsCount > 0 {
                    Section("Last Sync Results") {
                        DataTypeRow(icon: "heart.fill", title: "Vitals", count: syncManager.syncedVitalsCount, color: .red)
                        DataTypeRow(icon: "figure.run", title: "Workouts", count: syncManager.syncedWorkoutsCount, color: .green)
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

                Section("Data Types") {
                    DataTypeRow(icon: "heart.fill", title: "Heart Rate", color: .red)
                    DataTypeRow(icon: "waveform.path.ecg", title: "HRV", color: .purple)
                    DataTypeRow(icon: "figure.walk", title: "Steps", color: .green)
                    DataTypeRow(icon: "flame.fill", title: "Active Calories", color: .orange)
                    DataTypeRow(icon: "figure.run", title: "Exercise Minutes", color: .cyan)
                    DataTypeRow(icon: "lungs.fill", title: "Blood Oxygen", color: .blue)
                    DataTypeRow(icon: "bed.double.fill", title: "Sleep", color: .indigo)
                    DataTypeRow(icon: "dumbbell.fill", title: "Workouts", color: .green)
                    DataTypeRow(icon: "scalemass.fill", title: "Body Mass", color: .gray)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authManager.signOut() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Sync & Settings")
        }
    }
}
