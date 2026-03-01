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

    static let defaultCategories: [HealthStatusCategory] = []

    static func from(sectionConfig: [AnyCodableValue]) -> [HealthStatusCategory] {
        return sectionConfig.compactMap { item -> HealthStatusCategory? in
            guard case .dictionary(let dict) = item else { return nil }
            let title = dict["title"]?.stringValue ?? dict["section_key"]?.stringValue ?? "Unknown"
            let icon = dict["icon"]?.stringValue ?? "circle.fill"
            let statusStr = dict["status"]?.stringValue ?? "gray"
            let summary = dict["assessment_title"]?.stringValue ?? dict["assessment_text"]?.stringValue ?? ""
            let status: HealthStatus = {
                switch statusStr.lowercased() {
                case "green": return .green
                case "yellow": return .yellow
                case "orange": return .orange
                case "red": return .red
                default: return .gray
                }
            }()
            let webPath: String? = {
                let key = dict["section_key"]?.stringValue ?? ""
                switch key {
                case "sleep": return "/sleep"
                case "labs", "hormones": return "/labs"
                case "body_comp", "brain", "imaging": return "/imaging"
                default: return nil
                }
            }()
            return HealthStatusCategory(name: title, icon: icon, status: status, summary: summary, webPath: webPath)
        }
    }
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

    static let allInsights: [KeyInsight] = []

    static func from(criticalAlerts: [CriticalAlert]) -> [KeyInsight] {
        // Deduplicate by title — take only the first occurrence of each unique title
        var seen = Set<String>()
        return criticalAlerts.compactMap { alert -> KeyInsight? in
            let normalizedTitle = alert.title.lowercased().trimmingCharacters(in: .whitespaces)
            guard !seen.contains(normalizedTitle) else { return nil }
            seen.insert(normalizedTitle)
            let severity: InsightSeverity = {
                switch alert.severityColor {
                case "red": return .critical
                case "orange": return .warning
                default: return .info
                }
            }()
            let emoji: String = {
                switch severity {
                case .critical: return "🚨"
                case .warning: return "⚠️"
                case .info: return "✅"
                }
            }()
            return KeyInsight(
                emoji: emoji,
                title: alert.title,
                detail: alert.message,
                severity: severity,
                actionType: severity == .info ? "WATCH" : "ACTION"
            )
        }
    }
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

    static let allRecommendations: [AppRecommendation] = []

    static func from(recommendations: [RecommendationItem]) -> [AppRecommendation] {
        // Deduplicate by normalized title
        var seen = Set<String>()
        return recommendations.compactMap { rec -> AppRecommendation? in
            let normalizedTitle = rec.title.lowercased().trimmingCharacters(in: .whitespaces)
            guard !seen.contains(normalizedTitle) else { return nil }
            seen.insert(normalizedTitle)
            let priority: RecommendationPriority = {
                switch rec.priority?.lowercased() {
                case "high", "urgent", "critical": return .high
                default: return .medium
                }
            }()
            let icon: String = {
                switch rec.category?.lowercased() {
                case "exercise", "fitness": return "dumbbell.fill"
                case "heart", "cardiac", "cardiovascular": return "heart.fill"
                case "hormones": return "cross.vial.fill"
                case "screening": return "calendar.badge.clock"
                case "supplements": return "pill.fill"
                case "medications": return "pill.circle.fill"
                case "brain", "neuro": return "brain.head.profile"
                case "lifestyle": return "flame.fill"
                default: return "stethoscope"
                }
            }()
            return AppRecommendation(
                icon: icon,
                title: rec.title,
                body: rec.body ?? "",
                priority: priority,
                category: rec.category ?? "General",
                actionURL: rec.actionURL,
                contactInfo: rec.contactInfo
            )
        }
    }
}
