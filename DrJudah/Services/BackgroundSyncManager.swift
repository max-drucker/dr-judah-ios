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
    /// v3 (2026-08-02): v2 run produced zero daily-total rows on-device (cause captured by new
    /// diagnostics); bump forces another full resync now that activity rows upload first and
    /// HK query errors are surfaced instead of swallowed.
    /// Bumping this forces a one-time purge of the bad rows + full 2-year vitals resync.
    private static let currentVitalsSchemaVersion = 3
    private let lastWorkoutsSyncKey = "lastWorkoutsSyncDate"
    private let workoutSchemaVersionKey = "workoutSyncSchemaVersion"
    /// v2 (2026-08-02): workouts capture elevation gain + weather temp from HK metadata — pace/HR
    /// analysis on Max's 400ft-climb loop was blind to grade and heat. Bump forces one full
    /// resync so historical workouts get backfilled in place (upsert on type+started_at).
    private static let currentWorkoutSchemaVersion = 2
    private let lastSleepSyncKey = "lastSleepSyncDate"
    private let sleepSchemaVersionKey = "sleepSyncSchemaVersion"
    /// v2 (2026-08-02): sleep syncs Watch-only with real source names. Previously Watch + iPhone +
    /// Eight Sleep (which also logs other people in the bed) all landed as one anonymous source,
    /// double/triple-counting every night. Bump forces purge + full 2-year sleep resync.
    private static let currentSleepSchemaVersion = 2
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
                let needsFullResync = defaults.integer(forKey: sleepSchemaVersionKey) < Self.currentSleepSchemaVersion
                let since = needsFullResync
                    ? fallbackSince
                    : lookbackDate(from: lastSleepSync, fallback: fallbackSince, days: 45)
                if needsFullResync {
                    syncProgress = "Rebuilding sleep history (one-time fix)…"
                    print("[DrJudah] Sleep schema migration → v\(Self.currentSleepSchemaVersion): purging multi-source sleep rows, full resync since \(since)")
                    try await SupabaseManager.shared.purgeAllSleep()
                }
                print("[DrJudah] Sleep sync since: \(since) (watermark: \(lastSleepSync?.description ?? "none"))")
                let sleepRecords = await healthKit.fetchSleepForSync(since: since)
                syncedSleepCount = sleepRecords.count
                syncProgress = "Uploading \(sleepRecords.count) sleep records…"
                try await SupabaseManager.shared.syncSleep(sleepRecords)
                let now = Date()
                lastSleepSync = now
                defaults.set(now, forKey: lastSleepSyncKey)
                if sleepRecords.isEmpty {
                    if needsFullResync {
                        errors.append("Sleep rebuild fetched 0 Watch-sourced records — migration not marked complete")
                    }
                } else {
                    defaults.set(Self.currentSleepSchemaVersion, forKey: sleepSchemaVersionKey)
                }
            } catch {
                errors.append("Sleep sync failed: \(error.localizedDescription)")
            }

            syncProgress = "Syncing workouts…"
            do {
                let needsFullResync = defaults.integer(forKey: workoutSchemaVersionKey) < Self.currentWorkoutSchemaVersion
                let since = needsFullResync
                    ? fallbackSince
                    : lookbackDate(from: lastWorkoutsSync, fallback: fallbackSince, days: 45)
                if needsFullResync {
                    syncProgress = "Backfilling workout elevation + weather (one-time)…"
                    print("[DrJudah] Workout schema migration → v\(Self.currentWorkoutSchemaVersion): full resync since \(since)")
                }
                print("[DrJudah] Workout sync since: \(since) (watermark: \(lastWorkoutsSync?.description ?? "none"))")
                let workoutRecords = await healthKit.fetchWorkoutsForSync(since: since)
                syncedWorkoutsCount = workoutRecords.count
                syncProgress = "Uploading \(workoutRecords.count) workouts…"
                try await SupabaseManager.shared.syncWorkouts(workoutRecords)
                let now = Date()
                lastWorkoutsSync = now
                defaults.set(now, forKey: lastWorkoutsSyncKey)
                if !workoutRecords.isEmpty {
                    defaults.set(Self.currentWorkoutSchemaVersion, forKey: workoutSchemaVersionKey)
                }
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
                let result = await healthKit.fetchVitalsForSync(since: since)
                let vitalRecords = result.vitals
                syncedVitalsCount = vitalRecords.count
                syncProgress = "Uploading \(vitalRecords.count) vitals…"
                try await SupabaseManager.shared.syncVitals(vitalRecords)
                let now = Date()
                lastVitalsSync = now
                defaults.set(now, forKey: lastVitalsSyncKey)
                if result.activityCount == 0 {
                    // Do NOT mark the schema migration complete — activity backfill didn't happen.
                    errors.append("Activity totals came back empty — \(result.activitySummary)")
                } else {
                    defaults.set(Self.currentVitalsSchemaVersion, forKey: vitalsSchemaVersionKey)
                    syncProgress = "Activity totals: \(result.activitySummary)"
                }
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
