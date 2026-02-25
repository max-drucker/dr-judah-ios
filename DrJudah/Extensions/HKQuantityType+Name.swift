import HealthKit

extension HKQuantityType {
    var displayName: String {
        switch self {
        case HKQuantityType(.heartRate): return "Heart Rate"
        case HKQuantityType(.restingHeartRate): return "Resting Heart Rate"
        case HKQuantityType(.heartRateVariabilitySDNN): return "HRV"
        case HKQuantityType(.oxygenSaturation): return "Blood Oxygen"
        case HKQuantityType(.respiratoryRate): return "Respiratory Rate"
        case HKQuantityType(.bodyTemperature): return "Body Temperature"
        case HKQuantityType(.bodyMass): return "Weight"
        case HKQuantityType(.bodyFatPercentage): return "Body Fat"
        case HKQuantityType(.stepCount): return "Steps"
        case HKQuantityType(.activeEnergyBurned): return "Active Calories"
        case HKQuantityType(.appleExerciseTime): return "Exercise Minutes"
        case HKQuantityType(.vo2Max): return "VO₂ Max"
        case HKQuantityType(.walkingHeartRateAverage): return "Walking HR Avg"
        default: return identifier
        }
    }
}
