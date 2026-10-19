import Foundation

public struct QuotaGroup: Identifiable, Codable {
    public var id: String { name }
    public var name: String
    public var weeklyRemaining: Double?
    public var weeklyResetText: String?
    public var fiveHourRemaining: Double?
    public var fiveHourResetText: String?

    public init(
        name: String,
        weeklyRemaining: Double? = nil,
        weeklyResetText: String? = nil,
        fiveHourRemaining: Double? = nil,
        fiveHourResetText: String? = nil
    ) {
        self.name = name
        self.weeklyRemaining = weeklyRemaining
        self.weeklyResetText = weeklyResetText
        self.fiveHourRemaining = fiveHourRemaining
        self.fiveHourResetText = fiveHourResetText
    }
}

public struct ServiceUsage: Identifiable, Codable {
    public var id: String { service.rawValue }
    public var service: AIService
    public var cost: Double
    public var budgetLimit: Double
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var requestCount: Int
    public var requestLimit: Int?
    public var statusText: String
    public var statusDetails: String
    public var isConfigured: Bool
    public var isOrgManaged: Bool
    public var orgBadge: String?
    public var isQuotaMode: Bool
    public var quotaPrimaryText: String?
    public var quotaSecondaryText: String?
    public var quotaPercent: Double?
    public var quotaGroups: [QuotaGroup]
    public var isError: Bool
    public var lastUpdated: Date

    public init(
        service: AIService,
        cost: Double = 0.0,
        budgetLimit: Double = 30.0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        requestCount: Int = 0,
        requestLimit: Int? = nil,
        statusText: String = "Non configuré",
        statusDetails: String = "",
        isConfigured: Bool = false,
        isOrgManaged: Bool = false,
        orgBadge: String? = nil,
        isQuotaMode: Bool = false,
        quotaPrimaryText: String? = nil,
        quotaSecondaryText: String? = nil,
        quotaPercent: Double? = nil,
        quotaGroups: [QuotaGroup] = [],
        isError: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.service = service
        self.cost = cost
        self.budgetLimit = budgetLimit
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.requestCount = requestCount
        self.requestLimit = requestLimit
        self.statusText = statusText
        self.statusDetails = statusDetails
        self.isConfigured = isConfigured
        self.isOrgManaged = isOrgManaged
        self.orgBadge = orgBadge
        self.isQuotaMode = isQuotaMode
        self.quotaPrimaryText = quotaPrimaryText
        self.quotaSecondaryText = quotaSecondaryText
        self.quotaPercent = quotaPercent
        self.quotaGroups = quotaGroups
        self.isError = isError
        self.lastUpdated = lastUpdated
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.service = try c.decode(AIService.self, forKey: .service)
        self.cost = try c.decodeIfPresent(Double.self, forKey: .cost) ?? 0.0
        self.budgetLimit = try c.decodeIfPresent(Double.self, forKey: .budgetLimit) ?? 30.0
        self.inputTokens = try c.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        self.outputTokens = try c.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        self.cacheReadTokens = try c.decodeIfPresent(Int.self, forKey: .cacheReadTokens) ?? 0
        self.requestCount = try c.decodeIfPresent(Int.self, forKey: .requestCount) ?? 0
        self.requestLimit = try c.decodeIfPresent(Int.self, forKey: .requestLimit)
        self.statusText = try c.decodeIfPresent(String.self, forKey: .statusText) ?? ""
        self.statusDetails = try c.decodeIfPresent(String.self, forKey: .statusDetails) ?? ""
        self.isConfigured = try c.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? false
        self.isOrgManaged = try c.decodeIfPresent(Bool.self, forKey: .isOrgManaged) ?? false
        self.orgBadge = try c.decodeIfPresent(String.self, forKey: .orgBadge)
        self.isQuotaMode = try c.decodeIfPresent(Bool.self, forKey: .isQuotaMode) ?? false
        self.quotaPrimaryText = try c.decodeIfPresent(String.self, forKey: .quotaPrimaryText)
        self.quotaSecondaryText = try c.decodeIfPresent(String.self, forKey: .quotaSecondaryText)
        self.quotaPercent = try c.decodeIfPresent(Double.self, forKey: .quotaPercent)
        self.quotaGroups = try c.decodeIfPresent([QuotaGroup].self, forKey: .quotaGroups) ?? []
        self.isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        self.lastUpdated = try c.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
    }

    public var percentUsed: Double {
        if isQuotaMode, let qp = quotaPercent {
            return qp
        }
        guard budgetLimit > 0 else { return 0.0 }
        return (cost / budgetLimit) * 100.0
    }

    /// Remaining percentage (0-100) for quota-based plans
    public var remainingPercent: Double {
        return max(0.0, min(100.0, 100.0 - percentUsed))
    }

    public var isWarning: Bool {
        if isQuotaMode {
            return remainingPercent <= 25.0 && remainingPercent > 10.0
        }
        return percentUsed >= 80.0 && percentUsed < 100.0
    }

    public var isOverBudget: Bool {
        if isQuotaMode {
            return remainingPercent <= 10.0
        }
        return percentUsed >= 100.0
    }
}

public struct DailyPoint: Identifiable, Codable {
    public var id: String { dateString }
    public var dateString: String // YYYY-MM-DD
    public var dayLabel: String   // e.g. "Lun", "Mar"
    public var cursorCost: Double
    public var antigravityCost: Double
    public var claudeCost: Double

    public init(
        dateString: String,
        dayLabel: String,
        cursorCost: Double = 0.0,
        antigravityCost: Double = 0.0,
        claudeCost: Double = 0.0
    ) {
        self.dateString = dateString
        self.dayLabel = dayLabel
        self.cursorCost = cursorCost
        self.antigravityCost = antigravityCost
        self.claudeCost = claudeCost
    }

    public var totalCost: Double {
        return cursorCost + antigravityCost + claudeCost
    }
}

public struct BudgetSummary: Codable {
    public var totalCost: Double
    public var totalBudget: Double
    public var monthName: String
    public var services: [ServiceUsage]
    public var dailyHistory: [DailyPoint]
    public var lastRefreshed: Date

    public init(
        totalCost: Double = 0.0,
        totalBudget: Double = 100.0,
        monthName: String = "",
        services: [ServiceUsage] = [],
        dailyHistory: [DailyPoint] = [],
        lastRefreshed: Date = Date()
    ) {
        self.totalCost = totalCost
        self.totalBudget = totalBudget
        self.monthName = monthName
        self.services = services
        self.dailyHistory = dailyHistory
        self.lastRefreshed = lastRefreshed
    }

    public var percentUsed: Double {
        guard totalBudget > 0 else { return 0.0 }
        return (totalCost / totalBudget) * 100.0
    }

    public var remainingBudget: Double {
        return max(0, totalBudget - totalCost)
    }

    public var isWarning: Bool {
        return percentUsed >= 80.0 && percentUsed < 100.0
    }

    public var isOverBudget: Bool {
        return percentUsed >= 100.0
    }
}
