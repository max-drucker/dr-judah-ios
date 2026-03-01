import Foundation
import HealthKit

struct TodayHealth {
    var steps: Double = 0
    var restingHeartRate: Double = 0
    var hrv: Double = 0
    var activeCalories: Double = 0
    var exerciseMinutes: Double = 0
    var bloodOxygen: Double = 0
    var respiratoryRate: Double = 0
    var bodyTemperature: Double = 0
    var weight: Double = 0

    // New data types
    var bloodGlucose: Double = 0           // mg/dL
    var bloodPressureSystolic: Double = 0   // mmHg
    var bloodPressureDiastolic: Double = 0  // mmHg
    var bodyFatPercentage: Double = 0       // %
    var leanBodyMass: Double = 0            // kg
    var boneMineralDensity: Double = 0      // g/cm²
    var vo2Max: Double = 0                  // mL/kg·min

    // 7-day averages for trend comparison
    var avgSteps: Double = 0
    var avgRestingHR: Double = 0
    var avgHRV: Double = 0
    var avgActiveCalories: Double = 0
    var avgExerciseMinutes: Double = 0
    var avgBloodOxygen: Double = 0
    var avgBloodGlucose: Double = 0
    var avgSystolic: Double = 0
    var avgDiastolic: Double = 0

    // Sparkline data (last 7 days)
    var stepsHistory: [(Date, Double)] = []
    var restingHRHistory: [(Date, Double)] = []
    var hrvHistory: [(Date, Double)] = []
    var activeCaloriesHistory: [(Date, Double)] = []
    var exerciseMinutesHistory: [(Date, Double)] = []
    var bloodOxygenHistory: [(Date, Double)] = []
    var bloodGlucoseHistory: [(Date, Double)] = []
    var systolicHistory: [(Date, Double)] = []
    var weightHistory: [(Date, Double)] = []
}

struct Workout: Identifiable {
    let id: UUID
    let type: HKWorkoutActivityType
    let duration: TimeInterval
    let calories: Double
    let distance: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let startDate: Date
    let endDate: Date

    var durationMinutes: Double { duration / 60 }

    var typeIcon: String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rowing"
        case .hiking: return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }

    var typeName: String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
}

struct SyncPayload {
    let vitals: [VitalRecord]
    let workouts: [WorkoutRecord]
    let sleepSessions: [SleepRecord]
}

struct VitalRecord: Codable {
    let metricType: String
    let value: Double
    let unit: String
    let recordedAt: Date
}

struct WorkoutRecord: Codable {
    let workoutType: String
    let durationMinutes: Double
    let caloriesBurned: Double?
    let distanceMeters: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let startedAt: Date
    let endedAt: Date
}

struct SleepRecord: Codable {
    let sleepStage: String
    let startedAt: Date
    let endedAt: Date
}

struct HealthInsight: Identifiable {
    let id = UUID()
    let icon: String
    let color: String
    let title: String
    let message: String
    let severity: InsightSeverity

    enum InsightSeverity: Int, Comparable {
        case info = 0
        case attention = 1
        case warning = 2
        case critical = 3

        static func < (lhs: InsightSeverity, rhs: InsightSeverity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
