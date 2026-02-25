import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    let store = HKHealthStore()

    @Published var todayHealth = TodayHealth()
    @Published var recentWorkouts: [Workout] = []
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
            HKQuantityType(.boneMineralDensity),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.vo2Max),
            HKQuantityType(.walkingHeartRateAverage),
            HKQuantityType(.bloodGlucose),
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

        // Basic vitals
        async let steps = fetchTodayCumulative(.stepCount, unit: .count())
        async let restHR = fetchTodayAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let hrv = fetchTodayAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let activeCal = fetchTodayCumulative(.activeEnergyBurned, unit: .kilocalorie())
        async let exercise = fetchTodayCumulative(.appleExerciseTime, unit: .minute())
        async let spo2 = fetchTodayAverage(.oxygenSaturation, unit: .percent())
        async let respRate = fetchTodayAverage(.respiratoryRate, unit: .count().unitDivided(by: .minute()))
        async let vo2max = fetchLatestValue(.vo2Max, unit: HKUnit(from: "ml/kg*min"))

        // New types
        async let glucose = fetchTodayAverage(.bloodGlucose, unit: HKUnit(from: "mg/dL"))
        async let systolic = fetchTodayAverage(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let diastolic = fetchTodayAverage(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let bodyFat = fetchLatestValue(.bodyFatPercentage, unit: .percent())
        async let leanMass = fetchLatestValue(.leanBodyMass, unit: .gramUnit(with: .kilo))
        async let bmd = fetchLatestValue(.boneMineralDensity, unit: HKUnit.gramUnit(with: .none).unitDivided(by: HKUnit(from: "cm^2")))

        let (s, rhr, h, ac, ex, sp, rr, v) = await (steps, restHR, hrv, activeCal, exercise, spo2, respRate, vo2max)
        let (gl, sys, dia, bf, lm, bd) = await (glucose, systolic, diastolic, bodyFat, leanMass, bmd)

        todayHealth.steps = s
        todayHealth.restingHeartRate = rhr
        todayHealth.hrv = h
        todayHealth.activeCalories = ac
        todayHealth.exerciseMinutes = ex
        todayHealth.bloodOxygen = sp * 100
        todayHealth.respiratoryRate = rr
        todayHealth.vo2Max = v
        todayHealth.bloodGlucose = gl
        todayHealth.bloodPressureSystolic = sys
        todayHealth.bloodPressureDiastolic = dia
        todayHealth.bodyFatPercentage = bf * 100
        todayHealth.leanBodyMass = lm
        todayHealth.boneMineralDensity = bd

        // 7-day averages
        async let avgS = fetchAverage(.stepCount, unit: .count(), days: 7, cumulative: true)
        async let avgRHR = fetchAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 7, cumulative: false)
        async let avgH = fetchAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 7, cumulative: false)
        async let avgAC = fetchAverage(.activeEnergyBurned, unit: .kilocalorie(), days: 7, cumulative: true)
        async let avgGL = fetchAverage(.bloodGlucose, unit: HKUnit(from: "mg/dL"), days: 7, cumulative: false)
        async let avgSys = fetchAverage(.bloodPressureSystolic, unit: .millimeterOfMercury(), days: 7, cumulative: false)
        async let avgDia = fetchAverage(.bloodPressureDiastolic, unit: .millimeterOfMercury(), days: 7, cumulative: false)

        let (as7, arhr7, ah7, aac7, agl7, asys7, adia7) = await (avgS, avgRHR, avgH, avgAC, avgGL, avgSys, avgDia)
        todayHealth.avgSteps = as7
        todayHealth.avgRestingHR = arhr7
        todayHealth.avgHRV = ah7
        todayHealth.avgActiveCalories = aac7
        todayHealth.avgBloodGlucose = agl7
        todayHealth.avgSystolic = asys7
        todayHealth.avgDiastolic = adia7

        // Sparklines
        todayHealth.stepsHistory = await fetchDailyValues(.stepCount, unit: .count(), days: 7, cumulative: true)
        todayHealth.restingHRHistory = await fetchDailyValues(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 7, cumulative: false)
        todayHealth.hrvHistory = await fetchDailyValues(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 7, cumulative: false)
        todayHealth.bloodGlucoseHistory = await fetchDailyValues(.bloodGlucose, unit: HKUnit(from: "mg/dL"), days: 7, cumulative: false)
        todayHealth.systolicHistory = await fetchDailyValues(.bloodPressureSystolic, unit: .millimeterOfMercury(), days: 7, cumulative: false)

        // Workouts
        recentWorkouts = await fetchRecentWorkouts(days: 1)

        // Generate insights
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

    private func fetchLatestValue(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
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

    // MARK: - Full Sync (2 years of data)

    func fetchAllForSync(since: Date) async -> SyncPayload {
        let metrics: [(HKQuantityTypeIdentifier, String, HKUnit)] = [
            (.heartRate, "heart_rate", .count().unitDivided(by: .minute())),
            (.restingHeartRate, "resting_heart_rate", .count().unitDivided(by: .minute())),
            (.heartRateVariabilitySDNN, "hrv", .secondUnit(with: .milli)),
            (.oxygenSaturation, "blood_oxygen", .percent()),
            (.stepCount, "steps", .count()),
            (.activeEnergyBurned, "active_calories", .kilocalorie()),
            (.basalEnergyBurned, "basal_calories", .kilocalorie()),
            (.appleExerciseTime, "exercise_minutes", .minute()),
            (.bodyMass, "weight", .gramUnit(with: .kilo)),
            (.vo2Max, "vo2_max", HKUnit(from: "ml/kg*min")),
            (.respiratoryRate, "respiratory_rate", .count().unitDivided(by: .minute())),
            (.bloodGlucose, "blood_glucose", HKUnit(from: "mg/dL")),
            (.bloodPressureSystolic, "blood_pressure_systolic", .millimeterOfMercury()),
            (.bloodPressureDiastolic, "blood_pressure_diastolic", .millimeterOfMercury()),
            (.bodyFatPercentage, "body_fat_percentage", .percent()),
            (.leanBodyMass, "lean_body_mass", .gramUnit(with: .kilo)),
            (.boneMineralDensity, "bone_mineral_density", HKUnit.gramUnit(with: .none).unitDivided(by: HKUnit(from: "cm^2"))),
            (.walkingHeartRateAverage, "walking_heart_rate_avg", .count().unitDivided(by: .minute())),
            (.flightsClimbed, "flights_climbed", .count()),
            (.distanceWalkingRunning, "distance", .meter()),
        ]

        var vitals: [VitalRecord] = []

        for (identifier, name, unit) in metrics {
            let samples = await fetchSamples(identifier, since: since, limit: 5000)
            for sample in samples {
                vitals.append(VitalRecord(
                    metricType: name,
                    value: sample.quantity.doubleValue(for: unit),
                    unit: unit.unitString,
                    recordedAt: sample.startDate
                ))
            }
        }

        // Workouts (last 2 years)
        let workoutRecords = await fetchRecentWorkouts(days: 730).map { w in
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

        // Sleep
        let sleepRecords = await fetchSleepData(since: since)

        return SyncPayload(vitals: vitals, workouts: workoutRecords, sleepSessions: sleepRecords)
    }

    private func fetchSamples(_ identifier: HKQuantityTypeIdentifier, since: Date, limit: Int = 5000) async -> [HKQuantitySample] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchSleepData(since: Date) async -> [SleepRecord] {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 5000, sortDescriptors: [sort]) { _, samples, _ in
                let records = (samples as? [HKCategorySample])?.compactMap { sample -> SleepRecord? in
                    let stage: String
                    if #available(iOS 16.0, *) {
                        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        case .asleepDeep: stage = "deep"
                        case .asleepREM: stage = "rem"
                        case .asleepCore: stage = "core"
                        case .awake: stage = "awake"
                        case .asleepUnspecified: stage = "asleep"
                        case .inBed: stage = "in_bed"
                        default: stage = "unknown"
                        }
                    } else {
                        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        case .asleep: stage = "asleep"
                        case .inBed: stage = "in_bed"
                        case .awake: stage = "awake"
                        default: stage = "unknown"
                        }
                    }
                    return SleepRecord(sleepStage: stage, startedAt: sample.startDate, endedAt: sample.endDate)
                } ?? []
                continuation.resume(returning: records)
            }
            store.execute(query)
        }
    }

    // MARK: - Insights (medical-grade)

    func generateInsights() -> [HealthInsight] {
        var insights: [HealthInsight] = []

        // Critical: Sustained high HR
        if todayHealth.restingHeartRate > 100 {
            insights.append(HealthInsight(
                icon: "heart.fill",
                color: "red",
                title: "Elevated Resting Heart Rate",
                message: "Resting HR is \(Int(todayHealth.restingHeartRate)) bpm — sustained above 100 may indicate tachycardia. Monitor closely.",
                severity: .critical
            ))
        } else if todayHealth.restingHeartRate > 0 && todayHealth.restingHeartRate < 40 {
            insights.append(HealthInsight(
                icon: "heart.fill",
                color: "red",
                title: "Low Resting Heart Rate",
                message: "Resting HR is \(Int(todayHealth.restingHeartRate)) bpm — below 40 may indicate bradycardia.",
                severity: .critical
            ))
        }

        // Critical: HRV drop > 30%
        if todayHealth.avgHRV > 0 && todayHealth.hrv > 0 {
            let dropPct = ((todayHealth.avgHRV - todayHealth.hrv) / todayHealth.avgHRV) * 100
            if dropPct > 30 {
                insights.append(HealthInsight(
                    icon: "waveform.path.ecg",
                    color: "red",
                    title: "Significant HRV Drop",
                    message: "HRV is \(Int(dropPct))% below your baseline (\(Int(todayHealth.hrv)) vs avg \(Int(todayHealth.avgHRV)) ms). Your autonomic nervous system is stressed.",
                    severity: .warning
                ))
            } else if dropPct > 15 {
                insights.append(HealthInsight(
                    icon: "waveform.path.ecg",
                    color: "orange",
                    title: "HRV Below Baseline",
                    message: "HRV is \(Int(dropPct))% below average. Consider lighter activity today.",
                    severity: .attention
                ))
            } else if dropPct < -10 {
                insights.append(HealthInsight(
                    icon: "arrow.up.heart.fill",
                    color: "green",
                    title: "Strong Recovery",
                    message: "HRV is \(Int(abs(dropPct)))% above your 7-day average — your body is well-recovered.",
                    severity: .info
                ))
            }
        }

        // Critical: Blood glucose
        if todayHealth.bloodGlucose > 200 {
            insights.append(HealthInsight(
                icon: "drop.fill",
                color: "red",
                title: "High Blood Glucose",
                message: "Glucose reading of \(Int(todayHealth.bloodGlucose)) mg/dL is significantly elevated. Monitor for sustained highs.",
                severity: .critical
            ))
        } else if todayHealth.bloodGlucose > 0 && todayHealth.bloodGlucose < 60 {
            insights.append(HealthInsight(
                icon: "drop.fill",
                color: "red",
                title: "Low Blood Glucose",
                message: "Glucose at \(Int(todayHealth.bloodGlucose)) mg/dL — hypoglycemic range. Consider eating something.",
                severity: .critical
            ))
        }

        // Critical: Blood pressure
        if todayHealth.bloodPressureSystolic > 160 || todayHealth.bloodPressureDiastolic > 100 {
            insights.append(HealthInsight(
                icon: "heart.circle.fill",
                color: "red",
                title: "High Blood Pressure",
                message: "BP at \(Int(todayHealth.bloodPressureSystolic))/\(Int(todayHealth.bloodPressureDiastolic)) mmHg is in hypertensive range.",
                severity: .critical
            ))
        }

        // If nothing noteworthy, show a reassuring message
        if insights.isEmpty {
            insights.append(HealthInsight(
                icon: "checkmark.seal.fill",
                color: "green",
                title: "All Clear",
                message: "Your vitals are within normal ranges today. Keep it up.",
                severity: .info
            ))
        }

        return insights.sorted { $0.severity > $1.severity }
    }
}
