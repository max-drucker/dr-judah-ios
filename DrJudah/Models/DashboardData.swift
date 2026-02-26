import Foundation

// MARK: - Dashboard Signals Response

struct DashboardSignalsResponse: Decodable {
    let signals: [String: Signal]?
    let vatChart: [ChartDataPoint]?
    let calcChart: [ChartDataPoint]?
    let criticalAlerts: [CriticalAlert]?
    let overdueScreenings: [OverdueScreening]?

    enum CodingKeys: String, CodingKey {
        case signals, vatChart, calcChart, criticalAlerts, overdueScreenings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.signals = try? container.decode([String: Signal].self, forKey: .signals)
        self.vatChart = try? container.decode([ChartDataPoint].self, forKey: .vatChart)
        self.calcChart = try? container.decode([ChartDataPoint].self, forKey: .calcChart)
        self.criticalAlerts = try? container.decode([CriticalAlert].self, forKey: .criticalAlerts)
        self.overdueScreenings = try? container.decode([OverdueScreening].self, forKey: .overdueScreenings)
    }
}

struct Signal: Decodable, Identifiable {
    var id: String { label }
    let label: String
    let value: Double?
    let unit: String?
    let emoji: String?
    let insight: String?
    let previous: Double?
    let delta: Double?
    let trend: String?
    let status: String?

    // API returns signals as a dict where key=label, no "label" field in the value
    // We inject the label from the key during decoding
    enum CodingKeys: String, CodingKey {
        case label, value, unit, emoji, insight, previous, delta, trend, status
        // Also accept API field names
        case units, flag
        case prevValue = "prev_value"
        case prevDate = "prev_date"
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.label = (try? container.decode(String.self, forKey: .label)) ?? ""
        self.value = (try? container.decode(Double.self, forKey: .value))
        self.unit = (try? container.decode(String.self, forKey: .unit)) ?? (try? container.decode(String.self, forKey: .units))
        self.emoji = try? container.decode(String.self, forKey: .emoji)
        self.insight = try? container.decode(String.self, forKey: .insight)
        self.previous = (try? container.decode(Double.self, forKey: .previous)) ?? (try? container.decode(Double.self, forKey: .prevValue))
        self.delta = try? container.decode(Double.self, forKey: .delta)
        self.trend = try? container.decode(String.self, forKey: .trend)
        self.status = try? container.decode(String.self, forKey: .status)
    }

    init(label: String, value: Double?, unit: String?, emoji: String?, insight: String?, previous: Double?, delta: Double?, trend: String?, status: String?) {
        self.label = label; self.value = value; self.unit = unit; self.emoji = emoji
        self.insight = insight; self.previous = previous; self.delta = delta; self.trend = trend; self.status = status
    }

    var trendArrow: String {
        switch trend {
        case "up": return "↑"
        case "down": return "↓"
        default: return "→"
        }
    }

    var statusColor: String {
        status ?? "gray"
    }
}

struct ChartDataPoint: Codable, Identifiable {
    var id: String { "\(date)-\(value)" }
    let date: String
    let value: Double
    let label: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
        if let doubleVal = try? container.decode(Double.self, forKey: .value) {
            self.value = doubleVal
        } else if let stringVal = try? container.decode(String.self, forKey: .value),
                  let parsed = Double(stringVal) {
            self.value = parsed
        } else {
            self.value = 0
        }
    }

    init(date: String, value: Double, label: String? = nil) {
        self.date = date
        self.value = value
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case date, value, label
    }

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

struct CriticalAlert: Decodable, Identifiable {
    var id: String { title }
    let title: String
    let message: String
    let severity: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case title, message, severity, category, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTitle = (try? container.decode(String.self, forKey: .title)) ?? (try? container.decode(String.self, forKey: .type)) ?? "Alert"
        // Convert snake_case type identifiers to readable titles
        self.title = CriticalAlert.formatTitle(rawTitle)
        self.message = (try? container.decode(String.self, forKey: .message)) ?? ""
        self.severity = try? container.decode(String.self, forKey: .severity)
        self.category = try? container.decode(String.self, forKey: .category)
    }

    private static func formatTitle(_ raw: String) -> String {
        // If it contains spaces already, it's a real title
        if raw.contains(" ") { return raw }
        // Convert snake_case to Title Case
        return raw
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lower = word.lowercased()
                // Keep common abbreviations uppercase
                let abbrevs = ["hr", "hrv", "bp", "ldl", "hdl", "bmi", "trt", "alm", "dxa", "crp"]
                if abbrevs.contains(lower) {
                    return lower.uppercased()
                }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    var severityColor: String {
        switch severity?.lowercased() {
        case "critical", "high": return "red"
        case "warning", "medium": return "orange"
        default: return "yellow"
        }
    }
}

struct OverdueScreening: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let lastDate: String?
    let dueDate: String?
    let status: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, lastDate, dueDate, status, notes
        case screeningType = "screening_type"
        case lastDone = "last_done"
        case nextDue = "next_due"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? (try? container.decode(String.self, forKey: .screeningType)) ?? "Unknown"
        self.lastDate = (try? container.decode(String.self, forKey: .lastDate)) ?? (try? container.decode(String.self, forKey: .lastDone))
        self.dueDate = (try? container.decode(String.self, forKey: .dueDate)) ?? (try? container.decode(String.self, forKey: .nextDue))
        self.status = try? container.decode(String.self, forKey: .status)
        self.notes = try? container.decode(String.self, forKey: .notes)
    }
}

// MARK: - Lab Stats Response

struct LabStatsResponse: Codable {
    let stats: [String: [LabDataPoint]]?

    init(from decoder: Decoder) throws {
        // Try as dict first
        if let container = try? decoder.container(keyedBy: DynamicCodingKeys.self) {
            var result: [String: [LabDataPoint]] = [:]
            // Check if there's a "stats" key
            if container.contains(DynamicCodingKeys(stringValue: "stats")!) {
                let nested = try container.decode([String: [LabDataPoint]].self, forKey: DynamicCodingKeys(stringValue: "stats")!)
                result = nested
            } else {
                // Treat the whole thing as the dict
                for key in container.allKeys {
                    if let points = try? container.decode([LabDataPoint].self, forKey: key) {
                        result[key.stringValue] = points
                    }
                }
            }
            self.stats = result.isEmpty ? nil : result
        } else {
            self.stats = nil
        }
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

struct LabDataPoint: Codable, Identifiable {
    var id: String { "\(date)-\(value)" }
    let date: String
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        if let doubleVal = try? container.decode(Double.self, forKey: .value) {
            self.value = doubleVal
        } else if let stringVal = try? container.decode(String.self, forKey: .value),
                  let parsed = Double(stringVal) {
            self.value = parsed
        } else {
            self.value = 0
        }
    }

    init(date: String, value: Double) {
        self.date = date
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case date, value
    }

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

// MARK: - Current State Response

struct CurrentStateResponse: Decodable {
    let report: AnyCodableValue?
    let vitalsSummary: [String: AnyCodableValue]?
    let bpSummary: [String: AnyCodableValue]?
    let labResults: [String: AnyCodableValue]?
    let dxa: [String: AnyCodableValue]?
    let screenings: [ScreeningItem]?
    let medications: [MedicationItem]?
    let supplements: [SupplementItem]?
    let recommendations: [RecommendationItem]?
    let healthMetrics: [AnyCodableValue]?
    let sectionConfig: [AnyCodableValue]?

    // Backward compat accessors
    var labs: [String: AnyCodableValue]? { labResults }
    var vitals: [String: AnyCodableValue]? { vitalsSummary }
    var bp: [String: AnyCodableValue]? { bpSummary }
    var meds: [MedicationItem]? { medications }

    enum CodingKeys: String, CodingKey {
        case report, vitalsSummary, bpSummary, labResults, dxa
        case screenings, medications, supplements, recommendations
        case healthMetrics, sectionConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.report = try? container.decode(AnyCodableValue.self, forKey: .report)
        self.vitalsSummary = try? container.decode([String: AnyCodableValue].self, forKey: .vitalsSummary)
        self.bpSummary = try? container.decode([String: AnyCodableValue].self, forKey: .bpSummary)
        self.labResults = try? container.decode([String: AnyCodableValue].self, forKey: .labResults)
        self.dxa = try? container.decode([String: AnyCodableValue].self, forKey: .dxa)
        self.screenings = try? container.decode([ScreeningItem].self, forKey: .screenings)
        self.medications = try? container.decode([MedicationItem].self, forKey: .medications)
        self.supplements = try? container.decode([SupplementItem].self, forKey: .supplements)
        self.recommendations = try? container.decode([RecommendationItem].self, forKey: .recommendations)
        self.healthMetrics = try? container.decode([AnyCodableValue].self, forKey: .healthMetrics)
        self.sectionConfig = try? container.decode([AnyCodableValue].self, forKey: .sectionConfig)
    }
}

struct ScreeningItem: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let lastDate: String?
    let nextDue: String?
    let status: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, status, notes
        case screeningType = "screening_type"
        case lastDone = "last_done"
        case nextDue = "next_due"
        case lastDate, nextDueAlt = "nextDue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? (try? container.decode(String.self, forKey: .screeningType)) ?? "Unknown"
        self.lastDate = (try? container.decode(String.self, forKey: .lastDate)) ?? (try? container.decode(String.self, forKey: .lastDone))
        self.nextDue = (try? container.decode(String.self, forKey: .nextDueAlt)) ?? (try? container.decode(String.self, forKey: .nextDue))
        self.status = try? container.decode(String.self, forKey: .status)
        self.notes = try? container.decode(String.self, forKey: .notes)
    }
}

struct MedicationItem: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let dose: String?
    let frequency: String?
    let purpose: String?

    enum CodingKeys: String, CodingKey {
        case name, dose, frequency, purpose, dosage, reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        self.dose = (try? container.decode(String.self, forKey: .dose)) ?? (try? container.decode(String.self, forKey: .dosage))
        self.frequency = try? container.decode(String.self, forKey: .frequency)
        self.purpose = (try? container.decode(String.self, forKey: .purpose)) ?? (try? container.decode(String.self, forKey: .reason))
    }
}

struct SupplementItem: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let dose: String?
    let frequency: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case name, dose, frequency, reason, dosage, benefit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        self.dose = (try? container.decode(String.self, forKey: .dose)) ?? (try? container.decode(String.self, forKey: .dosage))
        self.frequency = try? container.decode(String.self, forKey: .frequency)
        self.reason = (try? container.decode(String.self, forKey: .reason)) ?? (try? container.decode(String.self, forKey: .benefit))
    }
}

struct RecommendationItem: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String?
    let priority: String?
    let category: String?
    let actionURL: String?
    let contactInfo: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body, priority, category, actionURL, contactInfo
        case text, timeframe, who
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        // API uses "text" not "title"
        self.title = (try? container.decode(String.self, forKey: .title)) ?? (try? container.decode(String.self, forKey: .text)) ?? "Recommendation"
        self.body = (try? container.decode(String.self, forKey: .body)) ?? (try? container.decode(String.self, forKey: .who))
        self.priority = try? container.decode(String.self, forKey: .priority)
        self.category = (try? container.decode(String.self, forKey: .category)) ?? (try? container.decode(String.self, forKey: .timeframe))
        self.actionURL = try? container.decode(String.self, forKey: .actionURL)
        self.contactInfo = try? container.decode(String.self, forKey: .contactInfo)
    }
}

struct HealthMetricItem: Codable {
    let status: String?
    let summary: String?
    let icon: String?
    let detail: String?
}

// MARK: - AnyCodableValue for flexible JSON

enum AnyCodableValue: Codable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case array([AnyCodableValue])
    case dictionary([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let val = try? container.decode(Bool.self) {
            self = .bool(val)
        } else if let val = try? container.decode(Int.self) {
            self = .int(val)
        } else if let val = try? container.decode(Double.self) {
            self = .double(val)
        } else if let val = try? container.decode(String.self) {
            self = .string(val)
        } else if let val = try? container.decode([AnyCodableValue].self) {
            self = .array(val)
        } else if let val = try? container.decode([String: AnyCodableValue].self) {
            self = .dictionary(val)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let val): try container.encode(val)
        case .double(let val): try container.encode(val)
        case .int(let val): try container.encode(val)
        case .bool(let val): try container.encode(val)
        case .array(let val): try container.encode(val)
        case .dictionary(let val): try container.encode(val)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let val) = self { return val }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .double(let val): return val
        case .int(let val): return Double(val)
        case .string(let val): return Double(val)
        default: return nil
        }
    }
}

// MARK: - Hardcoded Health Status Categories

struct HealthStatusCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let status: HealthStatus
    let summary: String
    let webPath: String?

    enum HealthStatus: String {
        case green, yellow, orange, red, gray

        var color: String { rawValue }
    }

    static let defaultCategories: [HealthStatusCategory] = [
        HealthStatusCategory(name: "Sleep", icon: "bed.double.fill", status: .orange, summary: "72 avg score", webPath: "/sleep"),
        HealthStatusCategory(name: "Exercise", icon: "figure.run", status: .orange, summary: "Needs consistency", webPath: nil),
        HealthStatusCategory(name: "Labs", icon: "flask.fill", status: .green, summary: "LDL 44, HbA1c 5.2", webPath: "/labs"),
        HealthStatusCategory(name: "Heart", icon: "heart.fill", status: .yellow, summary: "Ca score 49, stable", webPath: nil),
        HealthStatusCategory(name: "Body Comp", icon: "figure.arms.open", status: .red, summary: "Muscle loss — 7th %ile", webPath: "/imaging"),
        HealthStatusCategory(name: "Hormones", icon: "cross.vial.fill", status: .orange, summary: "Free T low", webPath: "/labs"),
        HealthStatusCategory(name: "Brain", icon: "brain.head.profile", status: .green, summary: "MRI current", webPath: "/imaging"),
        HealthStatusCategory(name: "Nutrition", icon: "leaf.fill", status: .gray, summary: "Coming soon", webPath: nil),
    ]
}

// MARK: - Hardcoded Key Insights

struct KeyInsight: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
    let severity: InsightSeverity
    let actionType: String // "ACTION", "WATCH"

    enum InsightSeverity: String {
        case critical, warning, info
    }

    static let allInsights: [KeyInsight] = [
        KeyInsight(
            emoji: "🚨",
            title: "Muscle Loss Crisis",
            detail: "ALM Index 7.25 kg/m² puts you at the 7th percentile for your age — clinical sarcopenia territory. DXA confirmed appendicular lean mass is critically low. This is the #1 health priority right now.",
            severity: .critical,
            actionType: "ACTION"
        ),
        KeyInsight(
            emoji: "🚨",
            title: "Sympathetic Overdrive",
            detail: "Resting HR 91 bpm combined with HRV of only 23ms signals your autonomic nervous system is stuck in fight-or-flight. This pattern correlates with elevated cardiovascular risk and poor recovery.",
            severity: .critical,
            actionType: "ACTION"
        ),
        KeyInsight(
            emoji: "⚠️",
            title: "Diastolic BP Elevated",
            detail: "Diastolic BP averaging 89 mmHg despite Ramipril 2.5mg. This is borderline Stage 1 hypertension. Current dose may be insufficient — discuss increase to 5mg with your physician.",
            severity: .warning,
            actionType: "ACTION"
        ),
        KeyInsight(
            emoji: "✅",
            title: "CGM Looking Great",
            detail: "Average glucose 96 mg/dL with 99% time in range (70-140). Your metabolic health is excellent. HbA1c 5.2% confirms long-term glucose control is optimal.",
            severity: .info,
            actionType: "WATCH"
        ),
        KeyInsight(
            emoji: "🧬",
            title: "DNA Flagged 3 Supplement Gaps",
            detail: "Genetic analysis identified deficiencies in methylation (MTHFR), vitamin D metabolism (VDR), and omega-3 conversion (FADS1). Targeted supplementation recommended.",
            severity: .warning,
            actionType: "ACTION"
        ),
    ]
}

// MARK: - Hardcoded Recommendations

struct AppRecommendation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    let priority: RecommendationPriority
    let category: String
    let actionURL: String?
    let contactInfo: String?

    enum RecommendationPriority: String {
        case high = "HIGH"
        case medium = "MEDIUM"

        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            }
        }
    }

    static let allRecommendations: [AppRecommendation] = [
        AppRecommendation(
            icon: "dumbbell.fill",
            title: "Resistance Training + 150g Protein",
            body: "This is the #1 priority. Progressive resistance training 3-4x/week targeting all major muscle groups, combined with 150g+ daily protein intake. ALM Index at 7th percentile demands aggressive intervention. Consider creatine monohydrate 5g/day as well.",
            priority: .high,
            category: "Exercise",
            actionURL: nil,
            contactInfo: nil
        ),
        AppRecommendation(
            icon: "cross.vial.fill",
            title: "TRT Evaluation — Now Medically Necessary",
            body: "Free testosterone is persistently low despite optimization attempts. Combined with sarcopenia (7th percentile muscle mass), TRT evaluation is now medically justified. Discuss with endocrinologist — options include topical gel or weekly injections.",
            priority: .high,
            category: "Hormones",
            actionURL: nil,
            contactInfo: "Dr. Patel — Endocrinology"
        ),
        AppRecommendation(
            icon: "brain.head.profile",
            title: "Brain MRI — Next Due May 2026",
            body: "Routine surveillance brain MRI. Last scan was clear. Continue annual monitoring given family history. Schedule through Stanford Radiology.",
            priority: .medium,
            category: "Screening",
            actionURL: nil,
            contactInfo: "Stanford Radiology: (650) 723-6855"
        ),
        AppRecommendation(
            icon: "heart.fill",
            title: "Address Tachycardia",
            body: "Resting HR 91 bpm + HRV 23ms is concerning. Rule out: thyroid dysfunction (TSH was normal), sleep apnea, medication side effects, deconditioning. Consider a cardiology consult if persistent after lifestyle optimization. Beta-blocker may be warranted.",
            priority: .high,
            category: "Heart",
            actionURL: nil,
            contactInfo: "Dr. Chen — Cardiology"
        ),
        AppRecommendation(
            icon: "pill.fill",
            title: "3 New Genetically-Driven Supplements",
            body: "Based on DNA analysis: (1) Methylfolate 1mg/day (MTHFR variant), (2) Vitamin D3 5000 IU/day (VDR variant — poor absorption), (3) EPA/DHA 2g/day (FADS1 — poor omega conversion). All available on Amazon.",
            priority: .high,
            category: "Supplements",
            actionURL: "https://www.amazon.com",
            contactInfo: nil
        ),
        AppRecommendation(
            icon: "pill.circle.fill",
            title: "Continue Methylated B Vitamins",
            body: "Methylated B-complex 3-4x per week is appropriate given your MTHFR status. Don't take daily — excess methylation can cause anxiety and insomnia. Current protocol is working well per homocysteine levels.",
            priority: .high,
            category: "Supplements",
            actionURL: nil,
            contactInfo: nil
        ),
        AppRecommendation(
            icon: "heart.circle.fill",
            title: "Discuss Ramipril Dose Increase",
            body: "Current Ramipril 2.5mg is not adequately controlling diastolic BP (averaging 89 mmHg). Standard titration would be to 5mg. Discuss at next PCP visit. Monitor for dizziness or cough.",
            priority: .medium,
            category: "Medications",
            actionURL: nil,
            contactInfo: "Dr. Kim — Primary Care"
        ),
        AppRecommendation(
            icon: "flame.fill",
            title: "Anti-Inflammatory Protocol",
            body: "hs-CRP trending up suggests systemic inflammation. Protocol: (1) Omega-3 EPA/DHA 2g/day, (2) Curcumin with piperine 1g/day, (3) Reduce processed foods, (4) Prioritize sleep quality. Recheck hs-CRP in 3 months.",
            priority: .medium,
            category: "Lifestyle",
            actionURL: nil,
            contactInfo: nil
        ),
    ]
}
