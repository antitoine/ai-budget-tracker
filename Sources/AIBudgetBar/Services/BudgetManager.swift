import Foundation
import Combine
import AppKit
import WidgetKit

@MainActor
public final class BudgetManager: ObservableObject {
    @Published public var config: AppConfig
    @Published public var summary: BudgetSummary
    @Published public var isRefreshing: Bool = false
    @Published public var lastRefreshed: Date?

    private var refreshTimer: Timer?
    private let cursorTracker = CursorTracker()
    private let antigravityTracker = AntigravityTracker()
    private let claudeTracker = ClaudeTracker()
    private let codexTracker = CodexTracker()

    private var alertedThresholds: Set<Double> = []

    public static var cacheFileURL: URL {
        return AppConfig.configDirectoryURL.appendingPathComponent("cache.json")
    }

    public init() {
        let loadedConfig = AppConfig.load()
        self.config = loadedConfig

        if let cached = Self.loadCache() {
            self.summary = cached.applying(config: loadedConfig)
            self.lastRefreshed = cached.lastRefreshed
        } else {
            self.summary = BudgetSummary(
                totalCost: 0.0,
                totalBudget: loadedConfig.totalBudget,
                monthName: "Current Cycles",
                services: loadedConfig.activeServices.map { ServiceUsage(service: $0, budgetLimit: loadedConfig.budgetFor(service: $0)) },
                dailyHistory: Self.build7DayHistory(cursor: [:], antigravity: [:], claude: [:])
            )
        }

        setupTimer()
    }

    public func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        newConfig.save()
        // Apply switches immediately, including while a slow export is in flight.
        summary = summary.applying(config: newConfig)
        Self.saveCache(summary)
        WidgetCenter.shared.reloadAllTimelines()
        alertedThresholds.removeAll()
        setupTimer()
        Task {
            await refreshAll()
        }
    }

    public func setupTimer() {
        refreshTimer?.invalidate()
        let intervalSec = Double(max(1, config.refreshIntervalMinutes) * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSec, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    public func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // A save during an in-flight request must not publish the old configuration.
        while true {
            let cfg = config
            await refresh(using: cfg)
            if config == cfg { break }
        }
    }

    private func refresh(using cfg: AppConfig) async {
        async let cursorAsync = cursorTracker.fetchUsage(config: cfg)
        async let antigravityAsync = antigravityTracker.fetchUsage(config: cfg)
        async let claudeAsync = claudeTracker.fetchUsage(config: cfg)
        async let codexAsync = codexTracker.fetchUsage(config: cfg)

        let (cursorRes, antigravityRes, claudeRes, codexUsage) = await (cursorAsync, antigravityAsync, claudeAsync, codexAsync)
        guard config == cfg else { return }

        // Cursor's export can be slow or fail transiently: keep the last good value.
        let previousCursor = summary.services.first { $0.service == .cursor }
        var cursorCost = cursorRes.cost
        var cursorStatus = cursorRes.statusText
        var cursorDaily = cursorRes.dailyCosts
        var cursorRequests = cursorRes.requestCount
        if cfg.isEnabled(service: .cursor), cursorRes.isError, let prev = previousCursor, prev.cost > 0 {
            cursorCost = prev.cost
            cursorRequests = prev.requestCount
            cursorDaily = Dictionary(uniqueKeysWithValues: summary.dailyHistory.map { ($0.dateString, $0.cursorCost) })
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            cursorStatus = "\(cursorRes.statusText) • as of \(f.string(from: prev.lastUpdated))"
        }

        let cursorIsEnt = cfg.isEnabled(service: .cursor) && cfg.isEnterprise(service: .cursor)
        let cursorQuotaUsed = min(100.0, Double(cursorRequests) / 5.0)
        let cursorRemaining = max(0.0, 100.0 - cursorQuotaUsed)
        let cursorUsage = ServiceUsage(
            service: .cursor,
            cost: cursorIsEnt ? cursorCost : 0.0,
            budgetLimit: cfg.budgetFor(service: .cursor),
            requestCount: cursorRequests,
            requestLimit: nil,
            statusText: cursorStatus,
            statusDetails: cursorIsEnt ? BillingCycle.resetLabel(resetDay: cfg.cursorBillingResetDay) : "Rolling quota • Auto",
            isConfigured: cursorRes.isConfigured,
            isOrgManaged: cursorIsEnt,
            orgBadge: cursorIsEnt ? "🏢 Enterprise" : "👤 Plan",
            isQuotaMode: !cursorIsEnt,
            quotaPrimaryText: !cursorIsEnt ? String(format: "%.0f%% remaining", cursorRemaining) : nil,
            quotaSecondaryText: !cursorIsEnt ? "Available quota" : nil,
            quotaPercent: !cursorIsEnt ? cursorQuotaUsed : nil,
            isError: cursorRes.isError,
            lastUpdated: cursorRes.isError ? (previousCursor?.lastUpdated ?? Date()) : Date()
        )

        let agyIsEnt = cfg.isEnabled(service: .antigravity) && cfg.isEnterprise(service: .antigravity)
        let agyUsedPct = antigravityRes.rollingQuotaUsedPercent
        let agyRemainingPct = max(0.0, min(100.0, 100.0 - agyUsedPct))
        let antigravityUsage = ServiceUsage(
            service: .antigravity,
            cost: agyIsEnt ? antigravityRes.cost : 0.0,
            budgetLimit: cfg.budgetFor(service: .antigravity),
            inputTokens: antigravityRes.inputTokens,
            outputTokens: antigravityRes.outputTokens,
            cacheReadTokens: antigravityRes.cacheReadTokens,
            requestCount: antigravityRes.conversationCount,
            statusText: antigravityRes.statusText,
            statusDetails: agyIsEnt ? BillingCycle.resetLabel(resetDay: cfg.antigravityBillingResetDay) : "Real-time quotas (Weekly & 5h)",
            isConfigured: antigravityRes.isConfigured,
            isOrgManaged: agyIsEnt,
            orgBadge: agyIsEnt ? "🏢 Enterprise" : "👤 Plan",
            isQuotaMode: !agyIsEnt,
            quotaPrimaryText: !agyIsEnt ? (antigravityRes.quotaPrimaryText ?? String(format: "%.0f%% remaining", agyRemainingPct)) : nil,
            quotaSecondaryText: !agyIsEnt ? (antigravityRes.quotaSecondaryText ?? "Available quota") : nil,
            quotaPercent: !agyIsEnt ? agyUsedPct : nil,
            quotaGroups: !agyIsEnt ? antigravityRes.quotaGroups : [],
            isError: false,
            lastUpdated: Date()
        )

        let claudeIsEnt = cfg.isEnabled(service: .claude) && cfg.isEnterprise(service: .claude)
        let claudeLimit = cfg.budgetFor(service: .claude) > 0 ? cfg.budgetFor(service: .claude) : (claudeRes.detectedLimit ?? 2000.0)
        let claudeUsage = ServiceUsage(
            service: .claude,
            cost: claudeIsEnt ? claudeRes.cost : 0.0,
            budgetLimit: claudeLimit,
            inputTokens: claudeRes.inputTokens,
            outputTokens: claudeRes.outputTokens,
            cacheReadTokens: claudeRes.cacheReadTokens,
            statusText: claudeRes.statusText,
            statusDetails: claudeIsEnt ? BillingCycle.resetLabel(resetDay: cfg.claudeBillingResetDay) : "Rolling quota • Auto",
            isConfigured: claudeRes.isConfigured,
            isOrgManaged: claudeIsEnt,
            orgBadge: claudeIsEnt ? "🏢 Enterprise" : "👤 Plan",
            isQuotaMode: !claudeIsEnt,
            quotaPrimaryText: !claudeIsEnt ? "100% remaining" : nil,
            quotaSecondaryText: !claudeIsEnt ? "Available quota" : nil,
            quotaPercent: !claudeIsEnt ? 0.0 : nil,
            isError: claudeRes.isError,
            lastUpdated: Date()
        )

        let dailyPoints = Self.build7DayHistory(
            cursor: cursorIsEnt ? cursorDaily : [:],
            antigravity: agyIsEnt ? antigravityRes.dailyCosts : [:],
            claude: claudeIsEnt ? claudeRes.dailyCosts : [:]
        )

        let allServices = [cursorUsage, antigravityUsage, claudeUsage, codexUsage]
            .filter { cfg.isEnabled(service: $0.service) }
        let enterpriseTotalCost = allServices
            .filter { !$0.isQuotaMode }
            .reduce(0.0) { $0 + $1.cost }

        let newSummary = BudgetSummary(
            totalCost: enterpriseTotalCost,
            totalBudget: cfg.totalBudget,
            monthName: "Enterprise Budget",
            services: allServices,
            dailyHistory: dailyPoints,
            lastRefreshed: Date()
        )

        self.summary = newSummary
        self.lastRefreshed = Date()
        Self.saveCache(newSummary)

        // Tell the Notification Center widget to re-read cache.json
        WidgetCenter.shared.reloadAllTimelines()

        checkAlerts(for: newSummary)
    }

    private static func formatCompactTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    private func checkAlerts(for summary: BudgetSummary) {
        let percent = summary.percentUsed / 100.0

        for threshold in config.alertThresholds.sorted() {
            if percent >= threshold && !alertedThresholds.contains(threshold) {
                alertedThresholds.insert(threshold)
                let pctString = String(format: "%.0f%%", threshold * 100.0)
                let costStr = String(format: "%.2f %@", summary.totalCost, config.currency)
                let budgetStr = String(format: "%.2f %@", summary.totalBudget, config.currency)
                sendMacNotification(
                    title: "AI Budget Alert (\(pctString))",
                    message: "You have consumed \(costStr) of your \(budgetStr) budget."
                )
            }
        }
    }

    private func sendMacNotification(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"\(title)\" sound name \"Default\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private static func build7DayHistory(
        cursor: [String: Double],
        antigravity: [String: Double],
        claude: [String: Double]
    ) -> [DailyPoint] {
        let calendar = Calendar.current
        let today = Date()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "en_US")
        labelFormatter.dateFormat = "EEE"

        return (0..<7).reversed().compactMap { i in
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { return nil }
            let key = dayFormatter.string(from: date)
            return DailyPoint(
                dateString: key,
                dayLabel: labelFormatter.string(from: date).capitalized,
                cursorCost: cursor[key] ?? 0.0,
                antigravityCost: antigravity[key] ?? 0.0,
                claudeCost: claude[key] ?? 0.0
            )
        }
    }

    private static func saveCache(_ summary: BudgetSummary) {
        let fileURL = cacheFileURL
        try? FileManager.default.createDirectory(at: AppConfig.configDirectoryURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(summary) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func loadCache() -> BudgetSummary? {
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        return try? JSONDecoder().decode(BudgetSummary.self, from: data)
    }
}
