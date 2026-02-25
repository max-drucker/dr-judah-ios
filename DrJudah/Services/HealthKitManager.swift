import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    private let store = HKHealthStore()

    @Published var todayHealth = TodayHealth()
    @Published var recentWorkouts: [Workout] = []
    @Published var healthScore: Int = 0
    @Published var insights: [HealthInsight] = []
    @Published var isAuthorized = false
    @Published var isLoading = false

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.bodyTemperature),
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.bodyMassIndex),
            HKQuantityType(.leanBodyMass),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.vo2Max),
            HKQuantityType(.walkingHeartRateAverage),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
        ]
        return types
    }()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
        await fetchAllData()
    }

    func fetchAllData() async {
        isLoading = true
        defer { isLoading = false }

        async let steps = fetchTodayCumulative(.stepCount, unit: .count())
        async let restHR = fetchTodayAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let hrv = fetchTodayAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let activeCal = fetchTodayCumulative(.activeEnergyBurned, unit: .kilocalorie())
        async let exercise = fetchTodayCumulative(.appleExerciseTime, unit: .minute())
        async let spo2 = fetchTodayAverage(.oxygenSaturation, unit: .percent())

        let (s, rhr, h, ac, ex, sp) = await (steps, restHR, hrv, activeCal, exercise, spo2)
        todayHealth.steps = s
        todayHealth.restingHeartRate = rhr
        todayHealth.hrv = h
        todayHealth.activeCalories = ac
        todayHealth.exerciseMinutes = ex
        todayHealth.bloodOxygen = sp * 100 // convert from fraction

        // Fetch 7-day averages
        async let avgS = fetchAverage(.stepCount, unit: .count(), days: 7, cumulative: true)
        async let avgRHR = fetchAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 7, cumulative: false)
        async let avgH = fetchAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 7, cumulative: false)
        async let avgAC = fetchAverage(.activeEnergyBurned, unit: .kilocalorie(), days: 7, cumulative: true)

        let (as7, arhr7, ah7, aac7) = await (avgS, avgRHR, avgH, avgAC)
        todayHealth.avgSteps = as7
        todayHealth.avgRestingHR = arhr7
        todayHealth.avgHRV = ah7
        todayHealth.avgActiveCalories = aac7

        // Fetch sparklines
        todayHealth.stepsHistory = await fetchDailyValues(.stepCount, unit: .count(), days: 7, cumulative: true)
        todayHealth.restingHRHistory = await fetchDailyValues(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 7, cumulative: false)
        todayHealth.hrvHistory = await fetchDailyValues(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 7, cumulative: false)

        // Workouts
        recentWorkouts = await fetchRecentWorkouts(days: 1)

        // Calculate score & insights
        healthScore = calculateHealthScore()
        insights = generateInsights()
    }

    // MARK: - Queries

    private func fetchTodayCumulative(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchTodayAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, cumulative: Bool) async -> Double {
        let type = HKQuantityType(identifier)
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: now))!
        let end = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let options: HKStatisticsOptions = cumulative ? .cumulativeSum : .discreteAverage
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var total = 0.0
                var count = 0
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let val: Double?
                    if cumulative {
                        val = stats.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        val = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let v = val, v > 0 {
                        total += v
                        count += 1
                    }
                }
                continuation.resume(returning: count > 0 ? total / Double(count) : 0)
            }
            store.execute(query)
        }
    }

    private func fetchDailyValues(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, cumulative: Bool) async -> [(Date, Double)] {
        let type = HKQuantityType(identifier)
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: now))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let options: HKStatisticsOptions = cumulative ? .cumulativeSum : .discreteAverage
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var values: [(Date, Double)] = []
                results?.enumerateStatistics(from: start, to: now) { stats, _ in
                    let val: Double?
                    if cumulative {
                        val = stats.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        val = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    values.append((stats.startDate, val ?? 0))
                }
                continuation.resume(returning: values)
            }
            store.execute(query)
        }
    }

    func fetchRecentWorkouts(days: Int) async -> [Workout] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: 10, sortDescriptors: [sort]) { _, samples, _ in
                let workouts = (samples as? [HKWorkout])?.map { w in
                    Workout(
                        id: w.uuid,
                        type: w.workoutActivityType,
                        duration: w.duration,
                        calories: w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                        distance: w.totalDistance?.doubleValue(for: .meter()),
                        avgHeartRate: nil,
                        maxHeartRate: nil,
                        startDate: w.startDate,
                        endDate: w.endDate
                    )
                } ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    func fetchAllForSync(since: Date) async -> SyncPayload {
        // Fetch all vitals since last sync
        var vitals: [VitalRecord] = []
        let metrics: [(HKQuantityTypeIdentifier, String, HKUnit)] = [
            (.heartRate, "heart_rate", .count().unitDivided(by: .minute())),
            (.restingHeartRate, "resting_heart_rate", .count().unitDivided(by: .minute())),
            (.heartRateVariabilitySDNN, "hrv", .secondUnit(with: .milli)),
            (.oxygenSaturation, "blood_oxygen", .percent()),
            (.stepCount, "steps", .count()),
            (.activeEnergyBurned, "active_calories", .kilocalorie()),
            (.appleExerciseTime, "exercise_minutes", .minute()),
            (.bodyMass, "weight", .gramUnit(with: .kilo)),
            (.vo2Max, "vo2_max", HKUnit(from: "ml/kg*min")),
        ]

        for (identifier, name, unit) in metrics {
            let samples = await fetchSamples(identifier, since: since)
            for sample in samples {
                vitals.append(VitalRecord(
                    metricType: name,
                    value: sample.quantity.doubleValue(for: unit),
                    unit: unit.unitString,
                    recordedAt: sample.startDate
                ))
            }
        }

        let workoutRecords = await fetchRecentWorkouts(days: 7).map { w in
            WorkoutRecord(
                workoutType: w.typeName.lowercased(),
                durationMinutes: w.durationMinutes,
                caloriesBurned: w.calories,
                distanceMeters: w.distance,
                avgHeartRate: w.avgHeartRate,
                maxHeartRate: w.maxHeartRate,
                startedAt: w.startDate,
                endedAt: w.endDate
            )
        }

        return SyncPayload(vitals: vitals, workouts: workoutRecords, sleepSessions: [])
    }

    private func fetchSamples(_ identifier: HKQuantityTypeIdentifier, since: Date) async -> [HKQuantitySample] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1000, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Health Score

    func calculateHealthScore() -> Int {
        var score = 50.0

        // HRV component (higher is better)
        if todayHealth.avgHRV > 0 && todayHealth.hrv > 0 {
            let hrvRatio = todayHealth.hrv / todayHealth.avgHRV
            score += (hrvRatio - 1.0) * 30 // +/- 30 points based on HRV vs average
        }

        // Resting HR component (lower is better)
        if todayHealth.avgRestingHR > 0 && todayHealth.restingHeartRate > 0 {
            let hrRatio = todayHealth.restingHeartRate / todayHealth.avgRestingHR
            score -= (hrRatio - 1.0) * 20 // penalty for elevated HR
        }

        // Activity component
        if todayHealth.avgSteps > 0 {
            let stepRatio = min(todayHealth.steps / todayHealth.avgSteps, 1.5)
            score += (stepRatio - 0.5) * 10
        }

        // Exercise component
        if todayHealth.exerciseMinutes >= 30 {
            score += 10
        } else if todayHealth.exerciseMinutes >= 15 {
            score += 5
        }

        return max(0, min(100, Int(score)))
    }

    // MARK: - Insights

    func generateInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []

        if todayHealth.avgHRV > 0 && todayHealth.hrv > 0 {
            let delta = ((todayHealth.hrv - todayHealth.avgHRV) / todayHealth.avgHRV) * 100
            if delta > 10 {
                insights.append(HealthInsight(
                    icon: "arrow.up.heart.fill",
                    color: "green",
                    message: "Your HRV is \(Int(delta))% above your 7-day average — your body is well-recovered today."
                ))
            } else if delta < -15 {
                insights.append(HealthInsight(
                    icon: "heart.text.square.fill",
                    color: "orange",
                    message: "HRV is \(Int(abs(delta)))% below average. Consider lighter activity and extra rest today."
                ))
            }
        }

        if todayHealth.avgRestingHR > 0 && todayHealth.restingHeartRate > 0 {
            let delta = todayHealth.restingHeartRate - todayHealth.avgRestingHR
            if delta > 5 {
                insights.append(HealthInsight(
                    icon: "waveform.path.ecg",
                    color: "red",
                    message: "Resting HR is up \(Int(delta)) bpm this week — could be stress, poor sleep, or early illness."
                ))
            }
        }

        if todayHealth.steps < 2000 {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 14 {
                insights.append(HealthInsight(
                    icon: "figure.walk",
                    color: "yellow",
                    message: "You've been pretty sedentary today. Even a 10-minute walk helps."
                ))
            }
        }

        if insights.isEmpty {
            insights.append(HealthInsight(
                icon: "sparkles",
                color: "blue",
                message: "Looking good today! Keep up your healthy routine."
            ))
        }

        return insights
    }
}
