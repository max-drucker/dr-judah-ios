import Foundation

@MainActor
class APIManager: ObservableObject {
    static let shared = APIManager()

    @Published var signals: [String: Signal] = [:]
    @Published var vatChart: [ChartDataPoint] = []
    @Published var calcChart: [ChartDataPoint] = []
    @Published var criticalAlerts: [CriticalAlert] = []
    @Published var overdueScreenings: [OverdueScreening] = []

    @Published var labStats: [String: [LabDataPoint]] = [:]

    @Published var currentState: CurrentStateResponse?

    @Published var isLoadingDashboard = false
    @Published var isLoadingLabs = false
    @Published var isLoadingState = false
    @Published var dashboardError: String?
    @Published var labsError: String?
    @Published var stateError: String?

    private var dashboardCacheTime: Date?
    private var labsCacheTime: Date?
    private var stateCacheTime: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    var isLoading: Bool {
        isLoadingDashboard || isLoadingLabs || isLoadingState
    }

    // MARK: - Fetch All

    func fetchAll() async {
        async let d: () = fetchDashboardSignals()
        async let l: () = fetchLabStats()
        async let s: () = fetchCurrentState()
        _ = await (d, l, s)
    }

    // MARK: - Dashboard Signals

    func fetchDashboardSignals(force: Bool = false) async {
        if !force, let cacheTime = dashboardCacheTime, Date().timeIntervalSince(cacheTime) < cacheTTL {
            return
        }

        isLoadingDashboard = true
        dashboardError = nil
        defer { isLoadingDashboard = false }

        do {
            let data = try await request(path: "/api/dashboard/signals")
            let response = try JSONDecoder().decode(DashboardSignalsResponse.self, from: data)
            signals = response.signals ?? [:]
            vatChart = response.vatChart ?? []
            calcChart = response.calcChart ?? []
            criticalAlerts = response.criticalAlerts ?? []
            overdueScreenings = response.overdueScreenings ?? []
            dashboardCacheTime = Date()
        } catch {
            dashboardError = error.localizedDescription
            print("Dashboard signals error: \(error)")
        }
    }

    // MARK: - Lab Stats

    func fetchLabStats(force: Bool = false) async {
        if !force, let cacheTime = labsCacheTime, Date().timeIntervalSince(cacheTime) < cacheTTL {
            return
        }

        isLoadingLabs = true
        labsError = nil
        defer { isLoadingLabs = false }

        do {
            let data = try await request(path: "/api/labs/stats")
            let response = try JSONDecoder().decode(LabStatsResponse.self, from: data)
            labStats = response.stats ?? [:]
            labsCacheTime = Date()
        } catch {
            labsError = error.localizedDescription
            print("Lab stats error: \(error)")
        }
    }

    // MARK: - Current State

    func fetchCurrentState(force: Bool = false) async {
        if !force, let cacheTime = stateCacheTime, Date().timeIntervalSince(cacheTime) < cacheTTL {
            return
        }

        isLoadingState = true
        stateError = nil
        defer { isLoadingState = false }

        do {
            let data = try await request(path: "/api/current-state")
            let response = try JSONDecoder().decode(CurrentStateResponse.self, from: data)
            currentState = response
            stateCacheTime = Date()
        } catch {
            stateError = error.localizedDescription
            print("Current state error: \(error)")
        }
    }

    // MARK: - Network

    private func request(path: String) async throws -> Data {
        guard let url = URL(string: Config.apiBaseURL + path) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.setValue(Config.userEmail, forHTTPHeaderField: "X-User-Email")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    // MARK: - Cache Invalidation

    func invalidateCache() {
        dashboardCacheTime = nil
        labsCacheTime = nil
        stateCacheTime = nil
    }
}
