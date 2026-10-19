import Foundation

public final class ClaudeTracker {
    public init() {}

    public struct ClaudeResult {
        public let cost: Double
        public let detectedLimit: Double?
        public let inputTokens: Int
        public let outputTokens: Int
        public let cacheReadTokens: Int
        public let dailyCosts: [String: Double]
        public let statusText: String
        public let isConfigured: Bool
        public let isOrgManaged: Bool
        public let orgBadge: String?
        public let isError: Bool
    }

    private let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    public func fetchUsage(config: AppConfig) async -> ClaudeResult {
        guard config.isEnabled(service: .claude) else {
            return ClaudeResult(cost: 0, detectedLimit: nil, inputTokens: 0, outputTokens: 0,
                                cacheReadTokens: 0, dailyCosts: [:], statusText: "Disabled",
                                isConfigured: false, isOrgManaged: false, orgBadge: nil, isError: false)
        }
        let isEnt = config.isEnterprise(service: .claude)
        let badge = isEnt ? "🏢 Enterprise" : "👤 Personal"

        // 1. Try web session cookie if provided (100% automatic via claude.ai)
        let rawCookie = config.claudeSessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawCookie.isEmpty {
            let webRes = await fetchViaClaudeWeb(config: config, rawCookie: rawCookie)
            if webRes.isConfigured {
                return webRes
            }
        }

        // 2. Try Admin API key if provided
        let key = config.claudeAdminKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            let adminRes = await fetchViaAdminApi(config: config, adminKey: key)
            if adminRes.isConfigured {
                return adminRes
            }
        }

        // 3. Fallback to manual spend if configured
        if let manual = config.claudeManualSpend, manual > 0 {
            let limit = config.budgetFor(service: .claude)
            let pct = limit > 0 ? (manual / limit) * 100.0 : 0.0
            return ClaudeResult(
                cost: manual,
                detectedLimit: nil,
                inputTokens: 0,
                outputTokens: 0,
                cacheReadTokens: 0,
                dailyCosts: [:],
                statusText: "Cycle starting on \(config.claudeBillingResetDay) • Manual (\(String(format: "%.1f%%", pct)))",
                isConfigured: true,
                isOrgManaged: isEnt,
                orgBadge: badge,
                isError: false
            )
        }

        return ClaudeResult(
            cost: 0.0,
            detectedLimit: nil,
            inputTokens: 0,
            outputTokens: 0,
            cacheReadTokens: 0,
            dailyCosts: [:],
            statusText: "Not configured (Add your sessionKey cookie)",
            isConfigured: false,
            isOrgManaged: isEnt,
            orgBadge: badge,
            isError: false
        )
    }

    private func fetchViaClaudeWeb(config: AppConfig, rawCookie: String) async -> ClaudeResult {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            return generateErrorResult(message: "Invalid URL")
        }

        let cookieHeader: String
        if rawCookie.contains("sessionKey=") {
            cookieHeader = rawCookie
        } else {
            cookieHeader = "sessionKey=\(rawCookie)"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12.0
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")

        let isEnt = config.isEnterprise(service: .claude)
        let badge = isEnt ? "🏢 Enterprise" : "👤 Personal"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  !orgs.isEmpty else {
                return generateErrorResult(message: "Claude session expired")
            }

            // Check each organization for usage / extra_usage
            for org in orgs {
                guard let orgId = org["uuid"] as? String else { continue }
                let orgName = (org["name"] as? String) ?? "Organization"

                guard let usageUrl = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else { continue }
                var usageReq = URLRequest(url: usageUrl)
                usageReq.httpMethod = "GET"
                usageReq.timeoutInterval = 12.0
                usageReq.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
                usageReq.setValue("application/json", forHTTPHeaderField: "Accept")
                usageReq.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")

                guard let (uData, uResp) = try? await URLSession.shared.data(for: usageReq),
                      let uHttp = uResp as? HTTPURLResponse, (200...299).contains(uHttp.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: uData) as? [String: Any] else {
                    continue
                }

                // 1. Parse `extra_usage` (Claude Enterprise / Team monthly credit gauge in minor units / cents)
                if let extra = json["extra_usage"] as? [String: Any] {
                    let decimals = (extra["decimal_places"] as? Int) ?? 2
                    let divisor = pow(10.0, Double(decimals))
                    let usedRaw = Self.doubleValue(from: extra["used_credits"])
                    let limitRaw = Self.doubleValue(from: extra["monthly_limit"])

                    if let usedCredits = usedRaw {
                        let cost = usedCredits / divisor
                        let limit = limitRaw.map { $0 / divisor }
                        let effectiveLimit = limit ?? config.budgetFor(service: .claude)
                        let pct = effectiveLimit > 0 ? (cost / effectiveLimit) * 100.0 : 0.0

                        return ClaudeResult(
                            cost: cost,
                            detectedLimit: limit,
                            inputTokens: 0,
                            outputTokens: 0,
                            cacheReadTokens: 0,
                            dailyCosts: [:],
                            statusText: "Cycle starting on \(config.claudeBillingResetDay) • \(orgName) (\(String(format: "%.1f%%", pct)))",
                            isConfigured: true,
                            isOrgManaged: isEnt,
                            orgBadge: badge,
                            isError: false
                        )
                    }
                }

                // 2. Fallback: check `spend.used.amount` or top-level `amount_spent` / `cost`
                if let spend = json["spend"] as? [String: Any],
                   let used = spend["used"] as? [String: Any],
                   let amount = Self.doubleValue(from: used["amount"]) {
                    let cost = amount > 1000 ? amount / 100.0 : amount
                    return ClaudeResult(
                        cost: cost,
                        detectedLimit: nil,
                        inputTokens: 0,
                        outputTokens: 0,
                        cacheReadTokens: 0,
                        dailyCosts: [:],
                        statusText: "Cycle starting on \(config.claudeBillingResetDay) • \(orgName) • Auto sync",
                        isConfigured: true,
                        isOrgManaged: isEnt,
                        orgBadge: badge,
                        isError: false
                    )
                }

                if let topCost = Self.doubleValue(from: json["amount_spent"]) ?? Self.doubleValue(from: json["cost"]) {
                    return ClaudeResult(
                        cost: topCost,
                        detectedLimit: nil,
                        inputTokens: 0,
                        outputTokens: 0,
                        cacheReadTokens: 0,
                        dailyCosts: [:],
                        statusText: "Cycle starting on \(config.claudeBillingResetDay) • \(orgName) • Auto sync",
                        isConfigured: true,
                        isOrgManaged: isEnt,
                        orgBadge: badge,
                        isError: false
                    )
                }
            }
        } catch {
            // Fall through to error result
        }

        return generateErrorResult(message: "Claude connection failed")
    }

    private static func doubleValue(from any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String, let d = Double(s) { return d }
        return nil
    }

    private func fetchViaAdminApi(config: AppConfig, adminKey: String) async -> ClaudeResult {
        let cycleStart = BillingCycle.period(resetDay: config.claudeBillingResetDay).start
        let now = Date()

        let isoFormatter = ISO8601DateFormatter()
        let startStr = isoFormatter.string(from: cycleStart)
        let endStr = isoFormatter.string(from: now)

        var components = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")
        components?.queryItems = [
            URLQueryItem(name: "starting_at", value: startStr),
            URLQueryItem(name: "ending_at", value: endStr)
        ]

        guard let url = components?.url else {
            return generateErrorResult(message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let isEnt = config.isEnterprise(service: .claude)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return generateErrorResult(message: "API error")
            }

            var apiCost = 0.0
            for item in dataArray {
                let costVal = Self.doubleValue(from: item["cost"]) ?? (Self.doubleValue(from: item["amount"]) ?? 0.0)
                apiCost += costVal
            }

            return ClaudeResult(
                cost: apiCost,
                detectedLimit: nil,
                inputTokens: 0,
                outputTokens: 0,
                cacheReadTokens: 0,
                dailyCosts: [:],
                statusText: "Admin API • \(formatCurrency(apiCost, symbol: config.currency))",
                isConfigured: true,
                isOrgManaged: isEnt,
                orgBadge: isEnt ? "🏢 Enterprise" : "👤 Personal",
                isError: false
            )
        } catch {
            return generateErrorResult(message: "Network error")
        }
    }

    private func generateErrorResult(message: String) -> ClaudeResult {
        return ClaudeResult(
            cost: 0.0,
            detectedLimit: nil,
            inputTokens: 0,
            outputTokens: 0,
            cacheReadTokens: 0,
            dailyCosts: [:],
            statusText: message,
            isConfigured: false,
            isOrgManaged: false,
            orgBadge: nil,
            isError: true
        )
    }

    private func formatCurrency(_ value: Double, symbol: String) -> String {
        return String(format: "%.2f %@", value, symbol)
    }
}
