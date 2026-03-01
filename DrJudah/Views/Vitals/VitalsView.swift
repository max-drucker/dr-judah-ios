import SwiftUI

struct VitalsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Cardiac
                    vitalSection(
                        title: "Cardiac",
                        icon: "heart.fill",
                        color: .red,
                        vitals: cardiacVitals
                    )

                    // Activity
                    vitalSection(
                        title: "Activity",
                        icon: "figure.run",
                        color: .green,
                        vitals: activityVitals
                    )

                    // Body Composition
                    vitalSection(
                        title: "Body Composition",
                        icon: "figure.arms.open",
                        color: .purple,
                        vitals: bodyCompVitals
                    )

                    // Respiratory & Metabolic
                    vitalSection(
                        title: "Respiratory & Metabolic",
                        icon: "lungs.fill",
                        color: .blue,
                        vitals: respiratoryVitals
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                await healthKitManager.fetchAllData()
            }
            .navigationTitle("Vitals")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Section Builder

    private func vitalSection(title: String, icon: String, color: Color, vitals: [VitalItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(vitals) { vital in
                    VitalCard(
                        icon: vital.icon,
                        title: vital.title,
                        value: vital.value,
                        unit: vital.unit,
                        trend: vital.trend,
                        sparkline: vital.sparkline,
                        color: vital.color
                    )
                }
            }
        }
    }

    // MARK: - Vital Items

    private var cardiacVitals: [VitalItem] {
        [
            VitalItem(
                icon: "heart.fill",
                title: "Resting HR",
                value: fmt(healthKitManager.todayHealth.restingHeartRate),
                unit: "bpm",
                trend: trendDelta(healthKitManager.todayHealth.restingHeartRate, healthKitManager.todayHealth.avgRestingHR, invert: true),
                sparkline: healthKitManager.todayHealth.restingHRHistory.map { $0.1 },
                color: .red
            ),
            VitalItem(
                icon: "waveform.path.ecg",
                title: "HRV",
                value: fmt(healthKitManager.todayHealth.hrv),
                unit: "ms",
                trend: trendDelta(healthKitManager.todayHealth.hrv, healthKitManager.todayHealth.avgHRV),
                sparkline: healthKitManager.todayHealth.hrvHistory.map { $0.1 },
                color: .purple
            ),
            VitalItem(
                icon: "heart.circle.fill",
                title: "Blood Pressure",
                value: healthKitManager.todayHealth.bloodPressureSystolic > 0
                    ? "\(Int(healthKitManager.todayHealth.bloodPressureSystolic))/\(Int(healthKitManager.todayHealth.bloodPressureDiastolic))"
                    : "--/--",
                unit: "mmHg",
                trend: nil,
                sparkline: healthKitManager.todayHealth.systolicHistory.map { $0.1 },
                color: Color(hex: "DC2626")
            ),
        ]
    }

    private var activityVitals: [VitalItem] {
        [
            VitalItem(
                icon: "figure.walk",
                title: "Steps",
                value: fmt(healthKitManager.todayHealth.steps),
                unit: "",
                trend: trendDelta(healthKitManager.todayHealth.steps, healthKitManager.todayHealth.avgSteps),
                sparkline: healthKitManager.todayHealth.stepsHistory.map { $0.1 },
                color: .green
            ),
            VitalItem(
                icon: "flame.fill",
                title: "Active Cal",
                value: fmt(healthKitManager.todayHealth.activeCalories),
                unit: "kcal",
                trend: trendDelta(healthKitManager.todayHealth.activeCalories, healthKitManager.todayHealth.avgActiveCalories),
                sparkline: [],
                color: .orange
            ),
            VitalItem(
                icon: "timer",
                title: "Exercise",
                value: fmt(healthKitManager.todayHealth.exerciseMinutes),
                unit: "min",
                trend: nil,
                sparkline: [],
                color: .cyan
            ),
            VitalItem(
                icon: "wind",
                title: "VO₂ Max",
                value: healthKitManager.todayHealth.vo2Max > 0 ? String(format: "%.1f", healthKitManager.todayHealth.vo2Max) : "--",
                unit: "mL/kg/min",
                trend: nil,
                sparkline: [],
                color: .teal
            ),
        ]
    }

    private var bodyCompVitals: [VitalItem] {
        let weight = healthKitManager.todayHealth.weight
        // Calculate BMI: weight (lbs) / height (in)^2 * 703, height = 5'10" = 70 in
        let bmi = weight > 0 ? (weight / (70.0 * 70.0)) * 703.0 : 0
        return [
            VitalItem(
                icon: "scalemass.fill",
                title: "Weight",
                value: weight > 0 ? String(format: "%.1f", weight) : "--",
                unit: "lbs",
                trend: nil,
                sparkline: healthKitManager.todayHealth.weightHistory.map { $0.1 },
                color: .indigo
            ),
            VitalItem(
                icon: "figure.stand",
                title: "BMI",
                value: bmi > 0 ? String(format: "%.1f", bmi) : "--",
                unit: "",
                trend: nil,
                sparkline: [],
                color: .blue
            ),
            VitalItem(
                icon: "percent",
                title: "Body Fat",
                value: healthKitManager.todayHealth.bodyFatPercentage > 0 ? String(format: "%.1f", healthKitManager.todayHealth.bodyFatPercentage) : "--",
                unit: "%",
                trend: nil,
                sparkline: [],
                color: .purple
            ),
            VitalItem(
                icon: "figure.strengthtraining.traditional",
                title: "Lean Mass",
                value: healthKitManager.todayHealth.leanBodyMass > 0 ? String(format: "%.1f", healthKitManager.todayHealth.leanBodyMass) : "--",
                unit: "kg",
                trend: nil,
                sparkline: [],
                color: .green
            ),
            VitalItem(
                icon: "bone",
                title: "Bone Density",
                value: healthKitManager.todayHealth.boneMineralDensity > 0 ? String(format: "%.2f", healthKitManager.todayHealth.boneMineralDensity) : "--",
                unit: "g/cm²",
                trend: nil,
                sparkline: [],
                color: .mint
            ),
        ]
    }

    private var respiratoryVitals: [VitalItem] {
        [
            VitalItem(
                icon: "lungs.fill",
                title: "SpO₂",
                value: healthKitManager.todayHealth.bloodOxygen > 0 ? String(format: "%.0f", healthKitManager.todayHealth.bloodOxygen) : "--",
                unit: "%",
                trend: nil,
                sparkline: [],
                color: .blue
            ),
            VitalItem(
                icon: "lungs",
                title: "Resp Rate",
                value: healthKitManager.todayHealth.respiratoryRate > 0 ? String(format: "%.0f", healthKitManager.todayHealth.respiratoryRate) : "--",
                unit: "br/min",
                trend: nil,
                sparkline: [],
                color: .blue
            ),
            VitalItem(
                icon: "drop.fill",
                title: "Glucose",
                value: healthKitManager.todayHealth.bloodGlucose > 0 ? fmt(healthKitManager.todayHealth.bloodGlucose) : "--",
                unit: "mg/dL",
                trend: healthKitManager.todayHealth.bloodGlucose > 0
                    ? trendDelta(healthKitManager.todayHealth.bloodGlucose, healthKitManager.todayHealth.avgBloodGlucose, invert: true)
                    : nil,
                sparkline: healthKitManager.todayHealth.bloodGlucoseHistory.map { $0.1 },
                color: .orange
            ),
        ]
    }

    // MARK: - Helpers

    private func fmt(_ value: Double) -> String {
        if value == 0 { return "--" }
        if value >= 1000 { return String(format: "%.0f", value) }
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    private func trendDelta(_ current: Double, _ average: Double, invert: Bool = false) -> TrendInfo? {
        guard current > 0 && average > 0 else { return nil }
        let delta = current - average
        let pct = (delta / average) * 100
        return TrendInfo(delta: delta, percentage: pct, invertColor: invert)
    }
}

// MARK: - VitalItem

struct VitalItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let unit: String
    let trend: TrendInfo?
    let sparkline: [Double]
    let color: Color
}
