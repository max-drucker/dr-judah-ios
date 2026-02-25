import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Sync Health Data

    func syncHealthData(data: SyncPayload) async throws {
        // Sync vitals
        if !data.vitals.isEmpty {
            let rows = data.vitals.map { vital -> [String: AnyJSON] in
                [
                    "metric_type": .string(vital.metricType),
                    "value": .double(vital.value),
                    "unit": .string(vital.unit),
                    "recorded_at": .string(ISO8601DateFormatter().string(from: vital.recordedAt)),
                    "source": .string("apple_health"),
                ]
            }
            try await client.from("apple_health_vitals")
                .upsert(rows, onConflict: "user_id,metric_type,recorded_at")
                .execute()
        }

        // Sync workouts
        if !data.workouts.isEmpty {
            let rows = data.workouts.map { w -> [String: AnyJSON] in
                var row: [String: AnyJSON] = [
                    "workout_type": .string(w.workoutType),
                    "duration_minutes": .double(w.durationMinutes),
                    "started_at": .string(ISO8601DateFormatter().string(from: w.startedAt)),
                    "ended_at": .string(ISO8601DateFormatter().string(from: w.endedAt)),
                    "source": .string("apple_health"),
                ]
                if let cal = w.caloriesBurned { row["calories_burned"] = .double(cal) }
                if let dist = w.distanceMeters { row["distance_meters"] = .double(dist) }
                if let avgHR = w.avgHeartRate { row["avg_heart_rate"] = .double(avgHR) }
                if let maxHR = w.maxHeartRate { row["max_heart_rate"] = .double(maxHR) }
                return row
            }
            try await client.from("apple_health_workouts")
                .upsert(rows, onConflict: "user_id,workout_type,started_at")
                .execute()
        }

        // Sync sleep
        if !data.sleepSessions.isEmpty {
            let rows = data.sleepSessions.map { s -> [String: AnyJSON] in
                [
                    "sleep_stage": .string(s.sleepStage),
                    "started_at": .string(ISO8601DateFormatter().string(from: s.startedAt)),
                    "ended_at": .string(ISO8601DateFormatter().string(from: s.endedAt)),
                    "source": .string("apple_health"),
                ]
            }
            try await client.from("apple_health_sleep")
                .upsert(rows, onConflict: "user_id,sleep_stage,started_at")
                .execute()
        }
    }

    // MARK: - Ask Judah

    func askJudah(message: String, history: [ChatMessage], healthContext: String?) async throws -> String {
        let historyDicts = history.map { ["role": $0.role.rawValue, "content": $0.content] }

        var body: [String: Any] = [
            "message": message,
            "history": historyDicts,
            "model": "claude-opus-4-6",
        ]
        if let ctx = healthContext {
            body["healthContext"] = ctx
        }

        let url = URL(string: "\(Config.apiBaseURL)/api/ask")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = json["response"] as? String {
            return response
        }

        throw URLError(.badServerResponse)
    }
}
