import Foundation

public struct AppConfig: Codable, Equatable {
    public var currency: String
    public var globalMonthlyBudget: Double
    public var serviceBudgets: [String: Double]
    public var enterpriseServices: [String: Bool]
    public var antigravityQuotaMillions: Double
    public var alertThresholds: [Double]
    public var refreshIntervalMinutes: Int
    public var demoMode: Bool
    public var showSidebarWidgetOnLaunch: Bool

    // Billing cycle reset days
    public var cursorBillingResetDay: Int
    public var claudeBillingResetDay: Int
    public var antigravityBillingResetDay: Int

    // Cursor settings
    public var cursorSessionToken: String
    public var cursorApiKey: String
    public var cursorTeamId: String
    public var cursorManualSpend: Double?

    // Claude settings
    public var claudeAdminKey: String
    public var claudeSessionCookie: String
    public var claudeManualSpend: Double?

    // Antigravity settings
    public var antigravityScanBrainDir: Bool
    public var antigravityCustomBrainPath: String
    public var geminiApiKey: String

    public init(
        currency: String = "$",
        globalMonthlyBudget: Double = 1500.0,
        serviceBudgets: [String: Double] = [
            AIService.cursor.rawValue: 2000.0,
            AIService.claude.rawValue: 2000.0,
            AIService.antigravity.rawValue: 200.0
        ],
        enterpriseServices: [String: Bool] = [
            AIService.cursor.rawValue: true,
            AIService.claude.rawValue: true,
            AIService.antigravity.rawValue: false
        ],
        antigravityQuotaMillions: Double = 5.0,
        alertThresholds: [Double] = [0.50, 0.80, 1.00],
        refreshIntervalMinutes: Int = 15,
        demoMode: Bool = false,
        showSidebarWidgetOnLaunch: Bool = true,
        cursorBillingResetDay: Int = 16,
        claudeBillingResetDay: Int = 1,
        antigravityBillingResetDay: Int = 18,
        cursorSessionToken: String = "",
        cursorApiKey: String = "",
        cursorTeamId: String = "2963894",
        cursorManualSpend: Double? = nil,
        claudeAdminKey: String = "",
        claudeSessionCookie: String = "",
        claudeManualSpend: Double? = nil,
        antigravityScanBrainDir: Bool = true,
        antigravityCustomBrainPath: String = "",
        geminiApiKey: String = ""
    ) {
        self.currency = currency
        self.globalMonthlyBudget = globalMonthlyBudget
        self.serviceBudgets = serviceBudgets
        self.enterpriseServices = enterpriseServices
        self.antigravityQuotaMillions = antigravityQuotaMillions
        self.alertThresholds = alertThresholds
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.demoMode = demoMode
        self.showSidebarWidgetOnLaunch = showSidebarWidgetOnLaunch
        self.cursorBillingResetDay = cursorBillingResetDay
        self.claudeBillingResetDay = claudeBillingResetDay
        self.antigravityBillingResetDay = antigravityBillingResetDay
        self.cursorSessionToken = cursorSessionToken
        self.cursorApiKey = cursorApiKey
        self.cursorTeamId = cursorTeamId
        self.cursorManualSpend = cursorManualSpend
        self.claudeAdminKey = claudeAdminKey
        self.claudeSessionCookie = claudeSessionCookie
        self.claudeManualSpend = claudeManualSpend
        self.antigravityScanBrainDir = antigravityScanBrainDir
        self.antigravityCustomBrainPath = antigravityCustomBrainPath
        self.geminiApiKey = geminiApiKey
    }

    // Custom Decodable with safe fallbacks for backwards compatibility
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "$"
        self.globalMonthlyBudget = try c.decodeIfPresent(Double.self, forKey: .globalMonthlyBudget) ?? 1500.0
        self.serviceBudgets = try c.decodeIfPresent([String: Double].self, forKey: .serviceBudgets) ?? [
            AIService.cursor.rawValue: 2000.0,
            AIService.claude.rawValue: 2000.0,
            AIService.antigravity.rawValue: 200.0
        ]
        self.enterpriseServices = try c.decodeIfPresent([String: Bool].self, forKey: .enterpriseServices) ?? [
            AIService.cursor.rawValue: true,
            AIService.claude.rawValue: true,
            AIService.antigravity.rawValue: false
        ]
        self.antigravityQuotaMillions = try c.decodeIfPresent(Double.self, forKey: .antigravityQuotaMillions) ?? 5.0
        self.alertThresholds = try c.decodeIfPresent([Double].self, forKey: .alertThresholds) ?? [0.50, 0.80, 1.00]
        self.refreshIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes) ?? 15
        self.demoMode = try c.decodeIfPresent(Bool.self, forKey: .demoMode) ?? false
        self.showSidebarWidgetOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .showSidebarWidgetOnLaunch) ?? true

        self.cursorBillingResetDay = try c.decodeIfPresent(Int.self, forKey: .cursorBillingResetDay) ?? 16
        self.claudeBillingResetDay = try c.decodeIfPresent(Int.self, forKey: .claudeBillingResetDay) ?? 1
        self.antigravityBillingResetDay = try c.decodeIfPresent(Int.self, forKey: .antigravityBillingResetDay) ?? 18

        self.cursorSessionToken = try c.decodeIfPresent(String.self, forKey: .cursorSessionToken) ?? ""
        self.cursorApiKey = try c.decodeIfPresent(String.self, forKey: .cursorApiKey) ?? ""
        self.cursorTeamId = try c.decodeIfPresent(String.self, forKey: .cursorTeamId) ?? "2963894"
        self.cursorManualSpend = try c.decodeIfPresent(Double.self, forKey: .cursorManualSpend)

        self.claudeAdminKey = try c.decodeIfPresent(String.self, forKey: .claudeAdminKey) ?? ""
        self.claudeSessionCookie = try c.decodeIfPresent(String.self, forKey: .claudeSessionCookie) ?? ""
        self.claudeManualSpend = try c.decodeIfPresent(Double.self, forKey: .claudeManualSpend)

        self.antigravityScanBrainDir = try c.decodeIfPresent(Bool.self, forKey: .antigravityScanBrainDir) ?? true
        self.antigravityCustomBrainPath = try c.decodeIfPresent(String.self, forKey: .antigravityCustomBrainPath) ?? ""
        self.geminiApiKey = try c.decodeIfPresent(String.self, forKey: .geminiApiKey) ?? ""
    }

    /// Real user home, even when running inside the sandboxed widget extension
    /// (where `homeDirectoryForCurrentUser` points to the container).
    public static var realHomeDirectory: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static var configDirectoryURL: URL {
        if let customEnv = ProcessInfo.processInfo.environment["AI_BUDGET_CONFIG_DIR"], !customEnv.isEmpty {
            return URL(fileURLWithPath: customEnv)
        }
        return realHomeDirectory.appendingPathComponent(".config/ai-budget-bar")
    }

    public static var configFileURL: URL {
        return configDirectoryURL.appendingPathComponent("config.json")
    }

    public static func load() -> AppConfig {
        let fileURL = configFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let initial = AppConfig()
            initial.save()
            return initial
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("[AIBudgetBar] Warning: Failed to load config at \(fileURL.path): \(error). Using defaults.")
            return AppConfig()
        }
    }

    public func save() {
        let dir = Self.configDirectoryURL
        let fileURL = Self.configFileURL

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o755
            ])
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path)
        } catch {
            // Silently ignore if permissions do not allow writing
        }
    }

    public func budgetFor(service: AIService) -> Double {
        return serviceBudgets[service.rawValue] ?? 0.0
    }

    public func isEnterprise(service: AIService) -> Bool {
        return enterpriseServices[service.rawValue] ?? (service != .antigravity)
    }

    public mutating func setEnterprise(_ isEnt: Bool, for service: AIService) {
        enterpriseServices[service.rawValue] = isEnt
    }

    /// Global Enterprise budget defined by the user (falls back to sum of enterprise service budgets if <= 0).
    public var totalBudget: Double {
        if globalMonthlyBudget > 0 {
            return globalMonthlyBudget
        }
        return AIService.allCases
            .filter { isEnterprise(service: $0) }
            .reduce(0.0) { $0 + budgetFor(service: $1) }
    }

    public func resetDay(for service: AIService) -> Int {
        switch service {
        case .cursor: return cursorBillingResetDay
        case .claude: return claudeBillingResetDay
        case .antigravity: return antigravityBillingResetDay
        }
    }
}

/// Billing cycles are computed in UTC, matching the Cursor dashboard export
/// and Claude's "reset at 00:00 UTC" behaviour.
public enum BillingCycle {
    public static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Start of the current cycle and the next reset date.
    public static func period(resetDay: Int, now: Date = Date()) -> (start: Date, nextReset: Date) {
        let cal = utcCalendar
        let day = max(1, min(28, resetDay))
        let comps = cal.dateComponents([.year, .month, .day], from: now)
        var start = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: day)) ?? now
        if (comps.day ?? 1) < day {
            start = cal.date(byAdding: .month, value: -1, to: start) ?? start
        }
        let next = cal.date(byAdding: .month, value: 1, to: start) ?? now
        return (start, next)
    }

    /// e.g. "Réinit. le 16 nov."
    public static func resetLabel(resetDay: Int, now: Date = Date()) -> String {
        let next = period(resetDay: resetDay, now: now).nextReset
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d MMM"
        return "Réinit. le \(f.string(from: next))"
    }
}
