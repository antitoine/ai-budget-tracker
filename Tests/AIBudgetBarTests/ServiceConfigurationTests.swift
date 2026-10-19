import XCTest
@testable import AIBudgetBar

final class ServiceConfigurationTests: XCTestCase {
    func testLegacyConfigKeepsSettingsAndEnablesServices() throws {
        let data = Data(#"{"currency":"€","cursorSessionToken":"saved-cookie","enterpriseServices":{"cursor":true,"claude":true,"antigravity":false},"serviceBudgets":{"cursor":99}}"#.utf8)
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(config.currency, "€")
        XCTAssertEqual(config.cursorSessionToken, "saved-cookie")
        XCTAssertEqual(config.activeServices, AIService.allCases)
        XCTAssertFalse(config.isEnterprise(service: .codex))
        XCTAssertEqual(config.budgetFor(service: .codex), 200)
    }

    func testToggleRoundTripPreservesCredentialsAndOtherSettings() throws {
        var config = AppConfig(cursorSessionToken: "saved-cookie", claudeSessionCookie: "saved-claude-cookie")
        config.setEnabled(false, for: .cursor)
        config.setEnabled(false, for: .codex)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.activeServices, [.antigravity, .claude])
        config.setEnabled(true, for: .cursor)
        XCTAssertEqual(config.cursorSessionToken, "saved-cookie")
        XCTAssertEqual(config.claudeSessionCookie, "saved-claude-cookie")
    }

    func testFallbackBudgetOnlyIncludesActiveEnterpriseServices() {
        var config = AppConfig(globalMonthlyBudget: 0)
        config.setEnabled(false, for: .cursor)
        config.setEnterprise(true, for: .codex)
        XCTAssertEqual(config.totalBudget, 2200)
        config.setEnabled(false, for: .claude)
        config.setEnabled(false, for: .codex)
        XCTAssertEqual(config.totalBudget, 0)
        config.globalMonthlyBudget = 1500
        XCTAssertEqual(config.totalBudget, 1500)
    }

    func testCacheFiltersDisabledCostsHistoryAndRows() {
        var config = AppConfig(globalMonthlyBudget: 0)
        config.setEnabled(false, for: .cursor)
        let cached = BudgetSummary(totalCost: 999, services: [
            ServiceUsage(service: .cursor, cost: 20),
            ServiceUsage(service: .claude, cost: 10),
            ServiceUsage(service: .antigravity, cost: 50, isQuotaMode: true),
            ServiceUsage(service: .codex, isQuotaMode: true)
        ], dailyHistory: [DailyPoint(dateString: "2026-10-19", dayLabel: "Mon", cursorCost: 20, antigravityCost: 50, claudeCost: 10)])
        let filtered = cached.applying(config: config)
        XCTAssertEqual(filtered.services.map(\.service), [.antigravity, .claude, .codex])
        XCTAssertEqual(filtered.totalCost, 10)
        XCTAssertEqual(filtered.totalBudget, 2000)
        XCTAssertEqual(filtered.dailyHistory.first?.totalCost, 10)
        for service in AIService.allCases { config.setEnabled(false, for: service) }
        let empty = cached.applying(config: config)
        XCTAssertTrue(empty.services.isEmpty)
        XCTAssertEqual(empty.totalCost, 0)
        XCTAssertEqual(empty.totalBudget, 0)
        XCTAssertEqual(empty.dailyHistory.first?.totalCost, 0)
    }

    func testBillingModeChangeClearsCachedAmountsUntilRefresh() {
        var config = AppConfig()
        config.setEnterprise(false, for: .claude)
        let cached = BudgetSummary(services: [ServiceUsage(service: .claude, cost: 45)])
        let filtered = cached.applying(config: config)
        XCTAssertEqual(filtered.totalCost, 0)
        let claude = filtered.services.first { $0.service == .claude }
        XCTAssertEqual(claude?.isQuotaMode, true)
        XCTAssertEqual(claude?.isConfigured, false)
    }

    func testNewlyEnabledServiceAppearsBeforeRefreshCompletes() {
        var config = AppConfig()
        for service in AIService.allCases { config.setEnabled(false, for: service) }
        config.setEnabled(true, for: .codex)
        let filtered = BudgetSummary().applying(config: config)
        XCTAssertEqual(filtered.services.map(\.service), [.codex])
        XCTAssertEqual(filtered.services.first?.quotaPrimaryText, "Unavailable")
    }
}
