import Foundation
import UniformTypeIdentifiers

/// Parses Omron Connect CSV exports and uploads to Supabase.
class OmronCSVImporter {
    struct BPReading {
        let systolic: Int
        let diastolic: Int
        let pulse: Int?
        let measuredAt: Date
        let notes: String?
    }

    enum ImportError: LocalizedError {
        case invalidFormat
        case noReadingsFound
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "The CSV file format is not recognized as an Omron export."
            case .noReadingsFound: return "No blood pressure readings found in the file."
            case .parseError(let msg): return "Parse error: \(msg)"
            }
        }
    }

    /// Parse an Omron Connect CSV export.
    /// Omron CSVs typically have columns like:
    /// Date, Time, Systolic, Diastolic, Pulse, Notes
    /// or: Date/Time, SYS(mmHg), DIA(mmHg), Pulse(bpm), etc.
    static func parse(csvString: String) throws -> [BPReading] {
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else {
            throw ImportError.invalidFormat
        }

        // Find column indices from header
        let header = lines[0].lowercased()
        let headerCols = parseCSVRow(lines[0]).map { $0.lowercased() }

        // Try to find relevant columns
        let sysIdx = headerCols.firstIndex(where: { $0.contains("sys") || $0.contains("systolic") })
        let diaIdx = headerCols.firstIndex(where: { $0.contains("dia") || $0.contains("diastolic") })
        let pulseIdx = headerCols.firstIndex(where: { $0.contains("pulse") || $0.contains("heart rate") || $0.contains("bpm") })

        // Date might be one column or split into date + time
        let dateIdx = headerCols.firstIndex(where: { $0.contains("date") && !$0.contains("time") })
        let timeIdx = headerCols.firstIndex(where: { $0.contains("time") && !$0.contains("date") })
        let dateTimeIdx = headerCols.firstIndex(where: { $0.contains("date") && $0.contains("time") })
            ?? headerCols.firstIndex(where: { $0.contains("measurement") })
        let notesIdx = headerCols.firstIndex(where: { $0.contains("note") || $0.contains("memo") })

        guard let sysCol = sysIdx, let diaCol = diaIdx else {
            // Try numeric fallback: assume Date, Time, Sys, Dia, Pulse
            return try parseFallback(lines: Array(lines.dropFirst()))
        }

        var readings: [BPReading] = []
        let dateFormatters = createDateFormatters()

        for lineIndex in 1..<lines.count {
            let cols = parseCSVRow(lines[lineIndex])
            guard cols.count > max(sysCol, diaCol) else { continue }

            guard let sys = Int(cols[sysCol].trimmingCharacters(in: .whitespaces)),
                  let dia = Int(cols[diaCol].trimmingCharacters(in: .whitespaces)),
                  sys > 0, dia > 0 else { continue }

            let pulse: Int? = pulseIdx.flatMap { idx in
                guard cols.count > idx else { return nil }
                return Int(cols[idx].trimmingCharacters(in: .whitespaces))
            }

            // Parse date
            var dateStr: String
            if let dtIdx = dateTimeIdx, cols.count > dtIdx {
                dateStr = cols[dtIdx].trimmingCharacters(in: .whitespaces)
            } else if let dIdx = dateIdx, cols.count > dIdx {
                dateStr = cols[dIdx].trimmingCharacters(in: .whitespaces)
                if let tIdx = timeIdx, cols.count > tIdx {
                    dateStr += " " + cols[tIdx].trimmingCharacters(in: .whitespaces)
                }
            } else {
                dateStr = cols[0].trimmingCharacters(in: .whitespaces)
                if cols.count > 1 {
                    let possibleTime = cols[1].trimmingCharacters(in: .whitespaces)
                    if possibleTime.contains(":") {
                        dateStr += " " + possibleTime
                    }
                }
            }

            let date = parseDate(dateStr, formatters: dateFormatters) ?? Date()

            let notes: String? = notesIdx.flatMap { idx in
                guard cols.count > idx else { return nil }
                let n = cols[idx].trimmingCharacters(in: .whitespaces)
                return n.isEmpty ? nil : n
            }

            readings.append(BPReading(systolic: sys, diastolic: dia, pulse: pulse, measuredAt: date, notes: notes))
        }

        guard !readings.isEmpty else {
            throw ImportError.noReadingsFound
        }

        return readings
    }

    /// Upload parsed readings to Supabase.
    static func upload(_ readings: [BPReading]) async throws {
        let tuples = readings.map { r in
            (systolic: r.systolic, diastolic: r.diastolic, pulse: r.pulse, measuredAt: r.measuredAt, notes: r.notes)
        }
        try await SupabaseManager.shared.uploadBloodPressureReadings(tuples)
    }

    // MARK: - Private

    private static func parseCSVRow(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    private static func parseFallback(lines: [String]) throws -> [BPReading] {
        var readings: [BPReading] = []
        let formatters = createDateFormatters()

        for line in lines {
            let cols = parseCSVRow(line).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 4 else { continue }

            // Try: col0=date, col1=time, col2=sys, col3=dia, col4=pulse
            let dateStr = cols.count > 1 && cols[1].contains(":") ? "\(cols[0]) \(cols[1])" : cols[0]
            let sysIdx = cols.count > 1 && cols[1].contains(":") ? 2 : 1
            let diaIdx = sysIdx + 1

            guard cols.count > diaIdx,
                  let sys = Int(cols[sysIdx]),
                  let dia = Int(cols[diaIdx]),
                  sys > 30, dia > 20 else { continue }

            let pulse = cols.count > diaIdx + 1 ? Int(cols[diaIdx + 1]) : nil
            let date = parseDate(dateStr, formatters: formatters) ?? Date()

            readings.append(BPReading(systolic: sys, diastolic: dia, pulse: pulse, measuredAt: date, notes: nil))
        }

        guard !readings.isEmpty else {
            throw ImportError.noReadingsFound
        }
        return readings
    }

    private static func createDateFormatters() -> [DateFormatter] {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy h:mm a",
            "M/d/yyyy H:mm",
            "M/d/yyyy h:mm a",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "dd/MM/yyyy HH:mm",
            "dd-MM-yyyy HH:mm",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }

    private static func parseDate(_ string: String, formatters: [DateFormatter]) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        // Try ISO8601
        let iso = ISO8601DateFormatter()
        return iso.date(from: string)
    }
}
