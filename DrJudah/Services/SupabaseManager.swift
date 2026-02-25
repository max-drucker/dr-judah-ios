import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private let userId = Config.userId
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Sync Health Data

    func syncHealthData(data: SyncPayload) async throws {
        // Sync vitals in batches of 500, deduplicating within each batch
        if !data.vitals.isEmpty {
            // Deduplicate: keep last value per (metricType, recordedAt)
            var seen = Set<String>()
            var dedupedVitals: [VitalRecord] = []
            for vital in data.vitals.reversed() {
                let key = "\(vital.metricType)|\(isoFormatter.string(from: vital.recordedAt))"
                if !seen.contains(key) {
                    seen.insert(key)
                    dedupedVitals.append(vital)
                }
            }
            dedupedVitals.reverse()

            let batches = stride(from: 0, to: dedupedVitals.count, by: 500).map {
                Array(dedupedVitals[$0..<min($0 + 500, dedupedVitals.count)])
            }
            for batch in batches {
                let rows = batch.map { vital -> [String: AnyJSON] in
                    [
                        "user_id": .string(userId),
                        "metric_type": .string(vital.metricType),
                        "value": .double(vital.value),
                        "unit": .string(vital.unit),
                        "recorded_at": .string(isoFormatter.string(from: vital.recordedAt)),
                        "source": .string("apple_health"),
                    ]
                }
                try await client.from("apple_health_vitals")
                    .upsert(rows, onConflict: "user_id,metric_type,recorded_at")
                    .execute()
            }
        }

        // Sync workouts
        if !data.workouts.isEmpty {
            let rows = data.workouts.map { w -> [String: AnyJSON] in
                var row: [String: AnyJSON] = [
                    "user_id": .string(userId),
                    "workout_type": .string(w.workoutType),
                    "duration_minutes": .double(w.durationMinutes),
                    "started_at": .string(isoFormatter.string(from: w.startedAt)),
                    "ended_at": .string(isoFormatter.string(from: w.endedAt)),
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

        // Sync sleep in batches, deduplicating
        if !data.sleepSessions.isEmpty {
            var seenSleep = Set<String>()
            var dedupedSleep: [SleepRecord] = []
            for s in data.sleepSessions.reversed() {
                let key = "\(s.sleepStage)|\(isoFormatter.string(from: s.startedAt))"
                if !seenSleep.contains(key) {
                    seenSleep.insert(key)
                    dedupedSleep.append(s)
                }
            }
            dedupedSleep.reverse()

            let batches = stride(from: 0, to: dedupedSleep.count, by: 500).map {
                Array(dedupedSleep[$0..<min($0 + 500, dedupedSleep.count)])
            }
            for batch in batches {
                let rows = batch.map { s -> [String: AnyJSON] in
                    [
                        "user_id": .string(userId),
                        "sleep_stage": .string(s.sleepStage),
                        "started_at": .string(isoFormatter.string(from: s.startedAt)),
                        "ended_at": .string(isoFormatter.string(from: s.endedAt)),
                        "source": .string("apple_health"),
                    ]
                }
                try await client.from("apple_health_sleep")
                    .upsert(rows, onConflict: "user_id,sleep_stage,started_at")
                    .execute()
            }
        }
    }

    // MARK: - Omron BP CSV Upload

    func uploadBloodPressureReadings(_ readings: [(systolic: Int, diastolic: Int, pulse: Int?, measuredAt: Date, notes: String?)]) async throws {
        let rows = readings.map { r -> [String: AnyJSON] in
            var row: [String: AnyJSON] = [
                "user_id": .string(userId),
                "systolic": .double(Double(r.systolic)),
                "diastolic": .double(Double(r.diastolic)),
                "measured_at": .string(isoFormatter.string(from: r.measuredAt)),
                "source": .string("omron"),
            ]
            if let pulse = r.pulse { row["pulse"] = .double(Double(pulse)) }
            if let notes = r.notes { row["notes"] = .string(notes) }
            return row
        }
        try await client.from("blood_pressure_readings")
            .upsert(rows, onConflict: "user_id,measured_at,source")
            .execute()
    }

    // MARK: - Ask Judah (matches web API format)

    func askJudah(message: String, history: [ChatMessage]) async throws -> String {
        let historyDicts = history.map { ["role": $0.role.rawValue, "content": $0.content] }

        let body: [String: Any] = [
            "message": message,
            "history": historyDicts,
            "model": "anthropic/claude-sonnet-4",
        ]

        let url = URL(string: "\(Config.apiBaseURL)/api/ask")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.userEmail, forHTTPHeaderField: "X-User-Email")
        request.timeoutInterval = 120

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AskJudah", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Web API returns "reply" not "response"
            if let reply = json["reply"] as? String {
                return reply
            }
            if let response = json["response"] as? String {
                return response
            }
        }

        throw URLError(.badServerResponse)
    }
}
