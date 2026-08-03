import Foundation
import BackgroundTasks
import Combine

@MainActor
class BackgroundSyncManager: ObservableObject {
    @Published var lastSyncDate: Date?
    @Published var lastVitalsSync: Date?
    @Published var lastWorkoutsSync: Date?
    @Published var lastSleepSync: Date?
    @Published var lastMedsSync: Date?
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var syncedVitalsCount: Int = 0
    @Published var syncedWorkoutsCount: Int = 0
    @Published var syncedSleepCount: Int = 0
    @Published var syncedMedicationsCount: Int = 0
    @Published var syncProgress: String = ""

    private let lastSyncAttemptKey = "lastHealthSyncDate"
    private let lastVitalsSyncKey = "lastVitalsSyncDate"
    private let vitalsSchemaVersionKey = "vitalsSyncSchemaVersion"
    /// v2 (2026-08-02): cumulative metrics (steps/distance/calories/exercise/flights) sync as
    /// Apple-deduped daily totals instead of raw samples. Raw samples double-counted Watch+iPhone.
    /// Bumping this forces a one-time purge of the bad rows + full 2-year vitals resync.
    private static let currentVitalsSchemaVersion = 2
    private let lastWorkoutsSyncKey = "lastWorkoutsSyncDate"
    private let lastSleepSyncKey = "lastSleepSyncDate"
    private let lastMedsSyncKey = "lastMedicationsSyncDate"
    private let healthKit = HealthKitManager()

    init() {
        let defaults = UserDefaults.standard
        lastSyncDate = defaults.object(forKey: lastSyncAttemptKey) as? Date
        lastVitalsSync = defaults.object(forKey: lastVitalsSyncKey) as? Date
        lastWorkoutsSync = defaults.object(forKey: lastWorkoutsSyncKey) as? Date
        lastSleepSync = defaults.object(forKey: lastSleepSyncKey) as? Date
        lastMedsSync = defaults.object(forKey: lastMedsSyncKey) as? Date
    }

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.drjudah.healthsync",
            using: nil
        ) { task in
            Task { @MainActor in
                let manager = BackgroundSyncManager()
                await manager.performSync()
                task.setTaskCompleted(success: true)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.drjudah.healthcheck",
            using: nil
        ) { task in
            Task { @MainActor in
                let hk = HealthKitManager()
                await hk.fetchAllData()
                NotificationManager.shared.checkAndNotify(health: hk.todayHealth)
                task.setTaskCompleted(success: true)
            }
        }
    }

    func scheduleBackgroundSync() {
        let syncRequest = BGProcessingTaskRequest(identifier: "com.drjudah.healthsync")
        syncRequest.requiresNetworkConnectivity = true
        syncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        let checkRequest = BGAppRefreshTaskRequest(identifier: "com.drjudah.healthcheck")
        checkRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 2)

        do {
            try BGTaskScheduler.shared.submit(syncRequest)
            try BGTaskScheduler.shared.submit(checkRequest)
        } catch {
            print("Background task scheduling failed: \(error)")
        }
    }

    /// Rolling lookback window for a sync watermark.
    ///
    /// HealthKit samples can be *written* long after their `startDate` (delayed Apple Watch sync,
    /// third-party apps like Strava/Peloton backfilling, manual retroactive entries). A strict
    /// "since last sync" predicate on `startDate` permanently loses those. Re-scanning a buffer
    /// window every sync is safe because all Supabase writes are upserts (idempotent).
    private func lookbackDate(from watermark: Date?, fallback: Date, days: Int) -> Date {
        guard let watermark else { return fallback }
        let shifted = Calendar.current.date(byAdding: .day, value: -days, to: watermark) ?? fallback
        return min(max(shifted, fallback), watermark)
    }

    func performSync() async {
        isSyncing = true
        syncError = nil
        syncedVitalsCount = 0
        syncedWorkoutsCount = 0
        syncedSleepCount = 0
        syncedMedicationsCount = 0
        defer { isSyncing = false }

        let defaults = UserDefaults.standard
        let fallbackSince = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        var errors: [String] = []
        var isAuthorized = false

        syncProgress = "Requesting HealthKit access…"
        do {
            try await healthKit.requestAuthorization()
            isAuthorized = true
        } catch {
            errors.append("HealthKit authorization failed: \(error.localizedDescription)")
        }

        if isAuthorized {
            syncProgress = "Syncing sleep…"
            do {
                let since = lookbackDate(from: lastSleepSync, fallback: fallbackSince, days: 45)
                print("[DrJudah] Sleep sync since: \(since) (watermark: \(lastSleepSync?.description ?? "none"))")
                let sleepRecords = await healthKit.fetchSleepForSync(since: since)
                syncedSleepCount = sleepRecords.count
                syncProgress = "Uploading \(sleepRecords.count) sleep records…"
                try await SupabaseManager.shared.syncSleep(sleepRecords)
                let now = Date()
                lastSleepSync = now
                defaults.set(now, forKey: lastSleepSyncKey)
            } catch {
                errors.append("Sleep sync failed: \(error.localizedDescription)")
            }

            syncProgress = "Syncing workouts…"
            do {
                let since = lookbackDate(from: lastWorkoutsSync, fallback: fallbackSince, days: 45)
                print("[DrJudah] Workout sync since: \(since) (watermark: \(lastWorkoutsSync?.description ?? "none"))")
                let workoutRecords = await healthKit.fetchWorkoutsForSync(since: since)
                syncedWorkoutsCount = workoutRecords.count
                syncProgress = "Uploading \(workoutRecords.count) workouts…"
                try await SupabaseManager.shared.syncWorkouts(workoutRecords)
                let now = Date()
                lastWorkoutsSync = now
                defaults.set(now, forKey: lastWorkoutsSyncKey)
            } catch {
                errors.append("Workout sync failed: \(error.localizedDescription)")
            }

            syncProgress = "Syncing medications…"
            do {
                let since = lookbackDate(from: lastMedsSync, fallback: fallbackSince, days: 45)
                print("[DrJudah] Medication sync since: \(since) (watermark: \(lastMedsSync?.description ?? "none"))")
                let medicationRecords = await healthKit.fetchMedicationsForSync(since: since)
                syncedMedicationsCount = medicationRecords.count
                syncProgress = "Uploading \(medicationRecords.count) medications…"
                try await SupabaseManager.shared.syncMedications(medicationRecords)
                let now = Date()
                lastMedsSync = now
                defaults.set(now, forKey: lastMedsSyncKey)
            } catch {
                errors.append("Medication sync failed: \(error.localizedDescription)")
            }

            syncProgress = "Syncing vitals…"
            do {
                let needsFullResync = defaults.integer(forKey: vitalsSchemaVersionKey) < Self.currentVitalsSchemaVersion
                // Shorter buffer: apple_health_vitals is by far the largest table.
                let since = needsFullResync
                    ? fallbackSince
                    : lookbackDate(from: lastVitalsSync, fallback: fallbackSince, days: 14)
                if needsFullResync {
                    syncProgress = "Rebuilding activity history (one-time fix)…"
                    print("[DrJudah] Vitals schema migration → v\(Self.currentVitalsSchemaVersion): purging over-counted cumulative rows, full resync since \(since)")
                    try await SupabaseManager.shared.purgeCumulativeVitals()
                }
                print("[DrJudah] Vitals sync since: \(since) (watermark: \(lastVitalsSync?.description ?? "none"))")
                let vitalRecords = await healthKit.fetchVitalsForSync(since: since)
                syncedVitalsCount = vitalRecords.count
                syncProgress = "Uploading \(vitalRecords.count) vitals…"
                try await SupabaseManager.shared.syncVitals(vitalRecords)
                let now = Date()
                lastVitalsSync = now
                defaults.set(now, forKey: lastVitalsSyncKey)
                defaults.set(Self.currentVitalsSchemaVersion, forKey: vitalsSchemaVersionKey)
            } catch {
                errors.append("Vitals sync failed: \(error.localizedDescription)")
            }
        }

        syncProgress = "Checking for anomalies…"
        if isAuthorized {
            await healthKit.fetchAllData()
            NotificationManager.shared.checkAndNotify(health: healthKit.todayHealth)
        }

        let attemptedAt = Date()
        lastSyncDate = attemptedAt
        defaults.set(attemptedAt, forKey: lastSyncAttemptKey)

        if errors.isEmpty {
            syncError = nil
            syncProgress = "Done!"
        } else {
            syncError = errors.joined(separator: "\n")
            syncProgress = "Sync completed with issues."
        }

        scheduleBackgroundSync()
    }
}
