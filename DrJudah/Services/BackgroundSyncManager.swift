import Foundation
import BackgroundTasks
import Combine

@MainActor
class BackgroundSyncManager: ObservableObject {
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var syncedVitalsCount: Int = 0
    @Published var syncedWorkoutsCount: Int = 0

    private let lastSyncKey = "lastHealthSyncDate"
    private let healthKit = HealthKitManager()

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
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
        syncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour

        let checkRequest = BGAppRefreshTaskRequest(identifier: "com.drjudah.healthcheck")
        checkRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 2) // 2 hours

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
        defer { isSyncing = false }

        let since = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        do {
            try await healthKit.requestAuthorization()
            let payload = await healthKit.fetchAllForSync(since: since)

            syncedVitalsCount = payload.vitals.count
            syncedWorkoutsCount = payload.workouts.count

            try await SupabaseManager.shared.syncHealthData(data: payload)

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)

            // Check for anomalies
            await healthKit.fetchAllData()
            NotificationManager.shared.checkAndNotify(health: healthKit.todayHealth)

            // Schedule next sync
            scheduleBackgroundSync()
        } catch {
            syncError = error.localizedDescription
        }
    }
}
