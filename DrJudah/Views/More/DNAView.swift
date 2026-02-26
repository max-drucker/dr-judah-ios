import SwiftUI

struct DNAView: View {
    @EnvironmentObject var apiManager: APIManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if apiManager.isLoadingState {
                    ProgressView("Loading DNA data…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "dna")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("DNA & Genetics")
                            .font(.title2.bold())

                        Text("Based on your genetic profile analysis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)

                    // Show DNA-relevant recommendations
                    let dnaRecs = (apiManager.currentState?.recommendations ?? []).filter {
                        let t = $0.title.lowercased()
                        return t.contains("dna") || t.contains("gene") || t.contains("genetic") || t.contains("mthfr") || t.contains("supplement")
                    }

                    if dnaRecs.isEmpty {
                        // Hardcoded genetic findings
                        ForEach(GeneticFinding.findings) { finding in
                            geneticCard(finding)
                                .padding(.horizontal)
                        }
                    } else {
                        ForEach(dnaRecs) { rec in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(rec.title)
                                    .font(.subheadline.bold())
                                if let body = rec.body {
                                    Text(body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let priority = rec.priority {
                                    Text(priority.uppercased())
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(priority == "immediate" ? .red : .orange))
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("DNA & Genetics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await apiManager.fetchCurrentState() }
        .refreshable { await apiManager.fetchCurrentState(force: true) }
    }

    private func geneticCard(_ finding: GeneticFinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(finding.gene)
                    .font(.subheadline.bold())
                Spacer()
                Text(finding.variant)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(finding.impact)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(finding.action)
                .font(.caption)
                .foregroundStyle(Color(hex: "3B82F6"))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

struct GeneticFinding: Identifiable {
    let id = UUID()
    let gene: String
    let variant: String
    let impact: String
    let action: String

    static let findings: [GeneticFinding] = [
        GeneticFinding(gene: "MTHFR", variant: "C677T heterozygous", impact: "Reduced methylation capacity — affects B vitamin metabolism", action: "Methylfolate 1mg/day recommended"),
        GeneticFinding(gene: "VDR", variant: "Taq1 variant", impact: "Poor vitamin D receptor binding — lower absorption", action: "Vitamin D3 5000 IU/day (higher than standard)"),
        GeneticFinding(gene: "FADS1", variant: "rs174547 T/T", impact: "Reduced omega-3 conversion from plant sources", action: "Direct EPA/DHA 2g/day from fish oil"),
        GeneticFinding(gene: "IL-6", variant: "GG genotype", impact: "Higher inflammatory response — elevated IL-6 production", action: "Anti-inflammatory protocol, monitor hs-CRP"),
        GeneticFinding(gene: "IL-10", variant: "CC genotype", impact: "Lower anti-inflammatory IL-10 — compounds IL-6 risk", action: "Curcumin + omega-3 for inflammation management"),
    ]
}
