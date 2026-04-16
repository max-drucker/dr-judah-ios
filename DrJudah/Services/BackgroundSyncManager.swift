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
                let sleepRecords = await healthKit.fetchSleepForSync(since: lastSleepSync ?? fallbackSince)
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
                let workoutRecords = await healthKit.fetchWorkoutsForSync(since: lastWorkoutsSync ?? fallbackSince)
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
                let medicationRecords = await healthKit.fetchMedicationsForSync(since: lastMedsSync ?? fallbackSince)
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
                let vitalRecords = await healthKit.fetchVitalsForSync(since: lastVitalsSync ?? fallbackSince)
                syncedVitalsCount = vitalRecords.count
                syncProgress = "Uploading \(vitalRecords.count) vitals…"
                try await SupabaseManager.shared.syncVitals(vitalRecords)
                let now = Date()
                lastVitalsSync = now
                defaults.set(now, forKey: lastVitalsSyncKey)
            } catch {
                errors.append("Vitals sync failed: \(error.localizedDescription)")
            }
        }

        syncProgress = "Checking for anomalies…"
        await healthKit.fetchAllData()
        NotificationManager.shared.checkAndNotify(health: healthKit.todayHealth)

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
