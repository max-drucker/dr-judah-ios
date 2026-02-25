import Foundation
import UserNotifications

/// Medical-grade notifications only. No fitness nags.
class NotificationManager {
    static let shared = NotificationManager()

    private let alertCooldownKey = "notification_cooldowns"

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert])
        } catch {
            return false
        }
    }

    func checkAndNotify(health: TodayHealth) {
        // Resting HR sustained above 100
        if health.restingHeartRate > 100 {
            scheduleAlert(
                id: "hr-tachycardia",
                title: "⚠️ Elevated Heart Rate",
                body: "Resting heart rate is \(Int(health.restingHeartRate)) bpm — sustained above 100 bpm. Monitor for symptoms like dizziness or chest pain.",
                cooldownHours: 6
            )
        }

        // Resting HR below 40
        if health.restingHeartRate > 0 && health.restingHeartRate < 40 {
            scheduleAlert(
                id: "hr-bradycardia",
                title: "⚠️ Low Heart Rate",
                body: "Resting heart rate is \(Int(health.restingHeartRate)) bpm — below 40 bpm may indicate bradycardia.",
                cooldownHours: 6
            )
        }

        // HRV drops more than 30% below personal baseline
        if health.avgHRV > 0 && health.hrv > 0 {
            let dropPct = ((health.avgHRV - health.hrv) / health.avgHRV) * 100
            if dropPct > 30 {
                scheduleAlert(
                    id: "hrv-severe-drop",
                    title: "⚠️ HRV Alert",
                    body: "HRV dropped \(Int(dropPct))% below your baseline (\(Int(health.hrv)) ms vs \(Int(health.avgHRV)) ms avg). Your autonomic nervous system is significantly stressed.",
                    cooldownHours: 12
                )
            }
        }

        // Blood glucose above 200
        if health.bloodGlucose > 200 {
            scheduleAlert(
                id: "glucose-high",
                title: "🚨 High Blood Glucose",
                body: "Glucose at \(Int(health.bloodGlucose)) mg/dL — significantly elevated. Monitor closely given your TCF7L2 TT genotype.",
                cooldownHours: 4
            )
        }

        // Blood glucose below 60
        if health.bloodGlucose > 0 && health.bloodGlucose < 60 {
            scheduleAlert(
                id: "glucose-low",
                title: "🚨 Low Blood Glucose",
                body: "Glucose at \(Int(health.bloodGlucose)) mg/dL — hypoglycemic range. Eat something with fast-acting carbohydrates.",
                cooldownHours: 2
            )
        }

        // Blood pressure systolic > 160 or diastolic > 100
        if health.bloodPressureSystolic > 160 || health.bloodPressureDiastolic > 100 {
            scheduleAlert(
                id: "bp-hypertensive",
                title: "⚠️ Hypertensive Blood Pressure",
                body: "Blood pressure at \(Int(health.bloodPressureSystolic))/\(Int(health.bloodPressureDiastolic)) mmHg. Re-check in 5 minutes; seek care if sustained.",
                cooldownHours: 4
            )
        }
    }

    // MARK: - Private

    private func scheduleAlert(id: String, title: String, body: String, cooldownHours: Int) {
        // Prevent notification spam with cooldown
        let cooldowns = UserDefaults.standard.dictionary(forKey: alertCooldownKey) as? [String: Date] ?? [:]
        if let lastFired = cooldowns[id],
           Date().timeIntervalSince(lastFired) < Double(cooldownHours * 3600) {
            return
        }

        // Update cooldown
        var updated = cooldowns
        updated[id] = Date()
        UserDefaults.standard.set(updated, forKey: alertCooldownKey)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
