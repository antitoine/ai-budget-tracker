#if canImport(AppKit)
import XCTest
@testable import AIBudgetBar

final class DisabledTrackerTests: XCTestCase {
    func testDisabledTrackersIgnoreSavedCredentialsAndManualSpend() async {
        var config = AppConfig(cursorSessionToken: "unused-cookie", claudeManualSpend: 99,
                               antigravityCustomBrainPath: "/nonexistent")
        for service in AIService.allCases { config.setEnabled(false, for: service) }
        let cursor = await CursorTracker().fetchUsage(config: config)
        let claude = await ClaudeTracker().fetchUsage(config: config)
        let antigravity = await AntigravityTracker().fetchUsage(config: config)
        XCTAssertFalse(cursor.isConfigured)
        XCTAssertFalse(claude.isConfigured)
        XCTAssertFalse(antigravity.isConfigured)
        XCTAssertEqual(cursor.cost, 0)
        XCTAssertEqual(claude.cost, 0)
        XCTAssertEqual(antigravity.cost, 0)
        XCTAssertTrue(antigravity.quotaGroups.isEmpty)
    }
}
#endif
