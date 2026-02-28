import SwiftUI

// MARK: - Health Domain Model

enum DomainStatus: String {
    case excellent, good, mixed, needsWork, critical, overdue, unknown

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .mixed: return "Mixed"
        case .needsWork: return "Needs Work"
        case .critical: return "Critical"
        case .overdue: return "Overdue"
        case .unknown: return "No Data"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(red: 0.2, green: 0.78, blue: 0.48) // emerald
        case .good: return .blue
        case .mixed: return Color(red: 0.96, green: 0.76, blue: 0.03) // amber
        case .needsWork: return .orange
        case .critical: return .red
        case .overdue: return .purple
        case .unknown: return .gray
        }
    }
}

struct HealthDomain: Identifiable {
    let id = UUID()
    let name: String
    let status: DomainStatus
}

// MARK: - Executive Summary View

struct ExecutiveSummaryView: View {
    @EnvironmentObject var apiManager: APIManager

    private var domains: [HealthDomain] {
        computeDomains(signals: apiManager.signals, overdueScreenings: apiManager.overdueScreenings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
                Text("Executive Summary")
                    .font(.title3.bold())
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Narrative
            Text(narrativeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Pill badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(domains) { domain in
                        DomainPill(domain: domain)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Narrative

    private var narrativeText: String {
        let criticals = domains.filter { $0.status == .critical }
        let needsWork = domains.filter { $0.status == .needsWork }
        let excellents = domains.filter { $0.status == .excellent || $0.status == .good }

        if criticals.count >= 2 {
            return "Multiple areas require urgent attention, including \(criticals.map(\.name).joined(separator: " and ")). Prioritize these with your care team. \(excellents.isEmpty ? "" : "\(excellents.first!.name) remains a bright spot.")"
        } else if criticals.count == 1 {
            return "\(criticals[0].name) needs immediate attention. \(needsWork.isEmpty ? "Other areas are tracking well." : "\(needsWork.map(\.name).joined(separator: ", ")) could use optimization.") \(excellents.isEmpty ? "" : "\(excellents.first!.name) is looking strong.")"
        } else if !needsWork.isEmpty {
            return "No critical issues right now. Focus on improving \(needsWork.map(\.name).joined(separator: ", ")). \(excellents.isEmpty ? "" : "\(excellents.first!.name) continues to perform well.")"
        } else {
            return "All domains are tracking well. Keep up the current regimen and continue monitoring."
        }
    }

    // MARK: - Domain Computation

    private func computeDomains(signals: [String: Signal], overdueScreenings: [OverdueScreening]) -> [HealthDomain] {
        var result: [HealthDomain] = []

        // 1. Lipids & Cardiac Risk
        if let apob = signals["ApoB"]?.value {
            let status: DomainStatus = apob < 60 ? .excellent : (apob < 80 ? .good : .needsWork)
            result.append(HealthDomain(name: "Lipids", status: status))
        } else {
            result.append(HealthDomain(name: "Lipids", status: .unknown))
        }

        // 2. Blood Sugar & Metabolic
        if let hba1c = signals["HbA1c"]?.value {
            let status: DomainStatus
            if hba1c <= 5.4 { status = .excellent }
            else if hba1c <= 5.6 { status = .good }
            else if hba1c <= 6.0 { status = .needsWork }
            else { status = .critical }
            result.append(HealthDomain(name: "Blood Sugar", status: status))
        } else {
            result.append(HealthDomain(name: "Blood Sugar", status: .unknown))
        }

        // 3. Inflammation
        if let crp = signals["hs-CRP"]?.value {
            let status: DomainStatus
            if crp < 0.5 { status = .excellent }
            else if crp < 1.0 { status = .good }
            else if crp < 3.0 { status = .needsWork }
            else { status = .critical }
            result.append(HealthDomain(name: "Inflammation", status: status))
        } else {
            result.append(HealthDomain(name: "Inflammation", status: .unknown))
        }

        // 4. Heart Rate & Recovery
        let rhr = signals["RHR"]?.value
        let hrv = signals["HRV"]?.value
        if let rhr = rhr {
            var status: DomainStatus
            if rhr > 85 { status = .critical }
            else if rhr > 75 { status = .needsWork }
            else if rhr > 65 { status = .good }
            else { status = .excellent }
            if let hrv = hrv, hrv < 25, status != .critical {
                status = status == .excellent ? .needsWork : .critical
            }
            result.append(HealthDomain(name: "Heart Rate", status: status))
        } else {
            result.append(HealthDomain(name: "Heart Rate", status: .unknown))
        }

        // 5. Blood Pressure
        if let dias = signals["Diastolic BP"]?.value ?? signals["Diastolic"]?.value {
            let status: DomainStatus
            if dias < 80 { status = .excellent }
            else if dias < 85 { status = .good }
            else if dias < 90 { status = .needsWork }
            else { status = .critical }
            result.append(HealthDomain(name: "Blood Pressure", status: status))
        } else {
            result.append(HealthDomain(name: "Blood Pressure", status: .unknown))
        }

        // 6. Hormonal & Anabolic
        let igf1 = signals["IGF-1"]?.value
        let shbg = signals["SHBG"]?.value
        let freeT = signals["Free T"]?.value ?? signals["Free Testosterone"]?.value
        if igf1 != nil || shbg != nil || freeT != nil {
            var status: DomainStatus = .good
            if let ft = freeT, ft < 10 { status = .critical }
            else if (igf1 != nil && igf1! < 170) || (shbg != nil && shbg! > 50) { status = .needsWork }
            result.append(HealthDomain(name: "Hormonal", status: status))
        } else {
            result.append(HealthDomain(name: "Hormonal", status: .unknown))
        }

        // 7. Thyroid
        if let tsh = signals["TSH"]?.value {
            let status: DomainStatus
            if tsh < 2.0 { status = .excellent }
            else if tsh < 2.5 { status = .good }
            else if tsh < 4.0 { status = .needsWork }
            else { status = .critical }
            result.append(HealthDomain(name: "Thyroid", status: status))
        } else {
            result.append(HealthDomain(name: "Thyroid", status: .unknown))
        }

        // 8. Body Composition
        let alm = signals["ALM Index"]?.value ?? signals["ALM"]?.value
        let vat = signals["VAT"]?.value ?? signals["Visceral Fat"]?.value
        if alm != nil || vat != nil {
            let vatGood = vat != nil && vat! < 100
            let almBad = alm != nil && alm! < 7.5
            let status: DomainStatus
            if almBad && vatGood { status = .mixed }
            else if almBad { status = .critical }
            else if vatGood { status = .good }
            else { status = .needsWork }
            result.append(HealthDomain(name: "Body Comp", status: status))
        } else {
            result.append(HealthDomain(name: "Body Comp", status: .unknown))
        }

        // 9. Fitness & Activity
        if let vo2 = signals["VO2 Max"]?.value {
            let status: DomainStatus
            if vo2 >= 40 { status = .excellent }
            else if vo2 >= 35 { status = .good }
            else { status = .needsWork }
            result.append(HealthDomain(name: "Fitness", status: status))
        } else {
            result.append(HealthDomain(name: "Fitness", status: .unknown))
        }

        // 10. Preventive Care
        let overdueCount = overdueScreenings.count
        if overdueCount == 0 {
            result.append(HealthDomain(name: "Preventive", status: .excellent))
        } else if overdueCount <= 1 {
            result.append(HealthDomain(name: "Preventive", status: .good))
        } else {
            result.append(HealthDomain(name: "Preventive", status: .overdue))
        }

        return result.filter { $0.status != .unknown }
    }
}

// MARK: - Domain Pill

struct DomainPill: View {
    let domain: HealthDomain

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(domain.status.color)
                .frame(width: 8, height: 8)
            Text(domain.name)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(domain.status.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(domain.status.color.opacity(0.25), lineWidth: 1)
        )
    }
}
