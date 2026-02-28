import Foundation

// MARK: - Top-level response

struct TrendsAPIResponse: Codable {
    let cardio: TrendsCardio?
    let metabolic: TrendsMetabolic?
    let sleep: TrendsSleep?
    let fitness: TrendsFitness?
    let correlations: TrendsCorrelations?
}

// MARK: - Cardio

struct TrendsCardio: Codable {
    let rhr: [TrendsDateValue]?
    let hrv: [TrendsDateValue]?
    let walkingHr: [TrendsDateValue]?
    let bp: [TrendsBP]?
}

struct TrendsDateValue: Codable, Identifiable {
    let date: String
    let value: Double
    var id: String { date }

    var parsedDate: Date {
        TrendsDateParser.parse(date)
    }
}

struct TrendsBP: Codable, Identifiable {
    let date: String
    let systolic: Double
    let diastolic: Double
    let pulse: Double?
    var id: String { date }

    var parsedDate: Date {
        TrendsDateParser.parse(date)
    }
}

// MARK: - Metabolic

struct TrendsMetabolic: Codable {
    let glucose: [TrendsGlucose]?
    let weight: [TrendsDateValue]?
    let activeCalories: [TrendsDateValue]?
}

struct TrendsGlucose: Codable, Identifiable {
    let date: String
    let avg: Double
    let min: Double
    let max: Double
    var id: String { date }

    var parsedDate: Date {
        TrendsDateParser.parse(date)
    }
}

// MARK: - Sleep

struct TrendsSleep: Codable {
    let byNight: [TrendsSleepNight]?
}

struct TrendsSleepNight: Codable, Identifiable {
    let night: String
    let total: Double
    let deep: Double?
    let rem: Double?
    let core: Double?
    var id: String { night }

    var parsedDate: Date {
        TrendsDateParser.parse(night)
    }
}

// MARK: - Fitness

struct TrendsFitness: Codable {
    let steps: [TrendsDateValue]?
    let exerciseMinutes: [TrendsDateValue]?
    let vo2Max: [TrendsDateValue]?
}

// MARK: - Correlations

struct TrendsCorrelations: Codable {
    let hrvVsSleep: TrendsCorrelation?
    let rhrVsExercise: TrendsCorrelation?
    let sleepVsRhr: TrendsCorrelation?
}

struct TrendsCorrelation: Codable, Identifiable {
    let label: String
    let xLabel: String
    let yLabel: String
    let r: Double
    let data: [TrendsCorrelationPoint]
    var id: String { label }
}

struct TrendsCorrelationPoint: Codable, Identifiable {
    let x: Double
    let y: Double
    var id: String { "\(x)-\(y)" }
}

// MARK: - Date Parser

enum TrendsDateParser {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func parse(_ string: String) -> Date {
        formatter.date(from: string) ?? Date()
    }
}
