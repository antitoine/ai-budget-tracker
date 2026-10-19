import XCTest
@testable import AIBudgetBar

final class CodexTrackerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1792400000)

    private func temporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        return home
    }

    private func event(date: Date, primary: Double = 25, secondary: Double = 60,
                       primaryReset: Double? = nil, secondaryReset: Double? = nil,
                       limitID: String = "codex") throws -> String {
        let object: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: date), "type": "event_msg",
            "payload": ["type": "token_count", "rate_limits": [
                "limit_id": limitID,
                "primary": ["used_percent": primary, "window_minutes": 300,
                            "resets_at": primaryReset ?? now.addingTimeInterval(3600).timeIntervalSince1970],
                "secondary": ["used_percent": secondary, "window_minutes": 10080,
                              "resets_at": secondaryReset ?? now.addingTimeInterval(86400).timeIntervalSince1970]
            ]]
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    func testLatestEventWinsAcrossFilesAndMalformedLinesAreIgnored() throws {
        let home = try temporaryHome()
        let newer = try event(date: now.addingTimeInterval(-30))
        let older = try event(date: now.addingTimeInterval(-3600), primary: 90)
        try (newer + "\nnot-json\n{\"unfinished\":").write(to: home.appendingPathComponent("sessions/first.jsonl"), atomically: true, encoding: .utf8)
        try (older + "\n").write(to: home.appendingPathComponent("sessions/second.jsonl"), atomically: true, encoding: .utf8)
        let usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertTrue(usage.isConfigured)
        XCTAssertTrue(usage.isQuotaMode)
        XCTAssertEqual(usage.cost, 0)
        XCTAssertEqual(usage.quotaPercent, 60)
        XCTAssertEqual(usage.quotaGroups.first?.fiveHourRemaining, 75)
        XCTAssertEqual(usage.quotaGroups.first?.weeklyRemaining, 40)
        XCTAssertEqual(usage.lastUpdated, now.addingTimeInterval(-30))
    }

    func testExpiredWindowIsUnavailableWhileOtherWindowRemainsUsable() throws {
        let home = try temporaryHome()
        let line = try event(date: now.addingTimeInterval(-30), primaryReset: now.addingTimeInterval(-1).timeIntervalSince1970)
        try line.write(to: home.appendingPathComponent("sessions/test.jsonl"), atomically: true, encoding: .utf8)
        let usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertNil(usage.quotaGroups.first?.fiveHourRemaining)
        XCTAssertEqual(usage.quotaGroups.first?.weeklyRemaining, 40)
        XCTAssertEqual(usage.quotaPercent, 60)
    }

    func testMissingAndExpiredSnapshotsNeverClaimFullQuota() throws {
        let home = try temporaryHome()
        var usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertFalse(usage.isConfigured)
        XCTAssertNil(usage.quotaPercent)
        XCTAssertEqual(usage.quotaPrimaryText, "Unavailable")
        let expired = now.addingTimeInterval(-1).timeIntervalSince1970
        let line = try event(date: now.addingTimeInterval(-30), primaryReset: expired, secondaryReset: expired)
        try line.write(to: home.appendingPathComponent("sessions/test.jsonl"), atomically: true, encoding: .utf8)
        usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertFalse(usage.isConfigured)
        XCTAssertNil(usage.quotaPercent)
        XCTAssertEqual(usage.quotaPrimaryText, "Unavailable")
    }

    func testArchivedSessionsAndSeparateModelLimits() throws {
        let home = try temporaryHome()
        let archived = home.appendingPathComponent("archived_sessions")
        try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
        let base = try event(date: now.addingTimeInterval(-60))
        let other = try event(date: now.addingTimeInterval(-10), primary: 99, limitID: "other-model")
        try (base + "\n" + other).write(to: archived.appendingPathComponent("test.jsonl"), atomically: true, encoding: .utf8)
        let usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertEqual(usage.quotaPercent, 60)
    }

    func testTailHandlesLargeTranscriptsAndOutOfRangeValues() throws {
        let home = try temporaryHome()
        let line = try event(date: now.addingTimeInterval(-10), primary: 120, secondary: -20)
        let text = String(repeating: "x", count: 600000) + "\n" + line + "\n"
        try text.write(to: home.appendingPathComponent("sessions/large.jsonl"), atomically: true, encoding: .utf8)
        let usage = CodexTracker.readUsage(home: home, budget: 200, now: now)
        XCTAssertEqual(usage.quotaGroups.first?.fiveHourRemaining, 0)
        XCTAssertEqual(usage.quotaGroups.first?.weeklyRemaining, 100)
    }

    func testHomePathPrecedence() {
        XCTAssertEqual(CodexTracker.homeURL(configuredPath: "/custom", environment: ["CODEX_HOME": "/env"]).path, "/custom")
        XCTAssertEqual(CodexTracker.homeURL(configuredPath: "", environment: ["CODEX_HOME": "/env"]).path, "/env")
        XCTAssertEqual(CodexTracker.homeURL(configuredPath: "~/codex", environment: [:]), AppConfig.realHomeDirectory.appendingPathComponent("codex"))
    }

    func testManualSpendAndDisableDoNotRequireLocalSessions() async {
        var config = AppConfig(codexHomePath: "/nonexistent", codexManualSpend: 42)
        config.setEnterprise(true, for: .codex)
        let manual = await CodexTracker().fetchUsage(config: config)
        XCTAssertEqual(manual.cost, 42)
        XCTAssertTrue(manual.isConfigured)
        XCTAssertFalse(manual.isQuotaMode)
        config.setEnabled(false, for: .codex)
        let disabled = await CodexTracker().fetchUsage(config: config)
        XCTAssertEqual(disabled.cost, 0)
        XCTAssertFalse(disabled.isConfigured)
    }
}
