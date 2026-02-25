import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func checkAndNotify(health: TodayHealth) {
        // HRV Drop
        if health.avgHRV > 0 && health.hrv > 0 {
            let drop = (health.avgHRV - health.hrv) / health.avgHRV
            if drop > 0.20 {
                scheduleNotification(
                    id: "hrv-drop",
                    title: "HRV Alert",
                    body: "Your HRV dropped significantly. Dr. Judah thinks you should take it easy today.",
                    delay: 1
                )
            }
        }

        // Resting HR Spike
        if health.avgRestingHR > 0 && health.restingHeartRate > 0 {
            let spike = (health.restingHeartRate - health.avgRestingHR) / health.avgRestingHR
            if spike > 0.10 {
                scheduleNotification(
                    id: "hr-spike",
                    title: "Heart Rate Alert",
                    body: "Resting heart rate is elevated. Could be stress, poor sleep, or early illness.",
                    delay: 1
                )
            }
        }

        // Inactivity
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 14 && health.steps < 2000 {
            scheduleNotification(
                id: "inactivity",
                title: "Time to Move",
                body: "You've been pretty sedentary today. Even a 10-minute walk helps.",
                delay: 1
            )
        }
    }

    func scheduleWeeklySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Health Summary"
        content.body = "Your weekly health summary is ready in Dr. Judah."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 19
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-summary", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleNotification(id: String, title: String, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
