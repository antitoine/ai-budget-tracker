import Foundation

public final class AntigravityTracker {
    public init() {}

    public struct AntigravityResult {
        public let cost: Double
        public let inputTokens: Int
        public let outputTokens: Int
        public let cacheReadTokens: Int
        public let conversationCount: Int
        public let rollingQuotaUsedPercent: Double
        public let quotaGroups: [QuotaGroup]
        public let quotaPrimaryText: String?
        public let quotaSecondaryText: String?
        public let dailyCosts: [String: Double] // YYYY-MM-DD -> Cost
        public let statusText: String
        public let isConfigured: Bool
    }

    private static var quotaCacheURL: URL {
        return AppConfig.configDirectoryURL.appendingPathComponent("agy_quotas.json")
    }

    public func fetchUsage(config: AppConfig) async -> AntigravityResult {
        guard config.isEnabled(service: .antigravity) else {
            return AntigravityResult(cost: 0, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0,
                                     conversationCount: 0, rollingQuotaUsedPercent: 0, quotaGroups: [],
                                     quotaPrimaryText: nil, quotaSecondaryText: nil, dailyCosts: [:],
                                     statusText: "Disabled", isConfigured: false)
        }
        // 1. Always try to fetch live real quotas from the running Antigravity language_server
        let liveGroups = await fetchLiveQuotaGroups() ?? Self.loadCachedQuotaGroups() ?? []
        if !liveGroups.isEmpty {
            Self.saveCachedQuotaGroups(liveGroups)
        }

        let brainURL: URL
        if let envBrain = ProcessInfo.processInfo.environment["ANTIGRAVITY_BRAIN_DIR"], !envBrain.isEmpty {
            brainURL = URL(fileURLWithPath: envBrain)
        } else if !config.antigravityCustomBrainPath.isEmpty {
            brainURL = URL(fileURLWithPath: config.antigravityCustomBrainPath)
        } else {
            brainURL = AppConfig.realHomeDirectory.appendingPathComponent(".gemini/antigravity/brain")
        }

        let fileManager = FileManager.default
        var totalInput = 0
        var totalOutput = 0
        var totalCache = 0
        var activeConversations = 0
        var dailyCosts: [String: Double] = [:]

        let now = Date()
        let rollingWindowSeconds: TimeInterval = 5.0 * 3600.0
        let windowStart = now.addingTimeInterval(-rollingWindowSeconds)
        var rollingWeightedUnits: Double = 0.0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIsoFormatter = ISO8601DateFormatter()
        fallbackIsoFormatter.formatOptions = [.withInternetDateTime]

        let dayKeyFormatter = DateFormatter()
        dayKeyFormatter.dateFormat = "yyyy-MM-dd"

        let isEnt = config.isEnterprise(service: .antigravity)
        let cycleStart = isEnt ? BillingCycle.period(resetDay: config.antigravityBillingResetDay).start : windowStart
        let cycleEnd = now

        if config.antigravityScanBrainDir && fileManager.fileExists(atPath: brainURL.path) {
            do {
                let items = try fileManager.contentsOfDirectory(at: brainURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

                for item in items {
                    var isDir: ObjCBool = false
                    guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else {
                        continue
                    }

                    let transcriptURL = item.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                    guard fileManager.fileExists(atPath: transcriptURL.path) else {
                        continue
                    }

                    var conversationHadActivity = false

                    if let data = try? Data(contentsOf: transcriptURL),
                       let contentString = String(data: data, encoding: .utf8) {
                        let lines = contentString.components(separatedBy: "\n")
                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }
                            guard let lineData = trimmed.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                                continue
                            }

                            if let dateStr = json["created_at"] as? String {
                                let date = isoFormatter.date(from: dateStr) ?? fallbackIsoFormatter.date(from: dateStr)
                                if let date = date, date <= cycleEnd {
                                    let inp = json["input_tokens"] as? Int ?? 0
                                    let out = json["output_tokens"] as? Int ?? 0
                                    let cache = json["cache_read_tokens"] as? Int ?? 0

                                    if date >= windowStart, (json["type"] as? String) == "PLANNER_RESPONSE" {
                                        let age = now.timeIntervalSince(date)
                                        let decayFactor = max(0.0, 1.0 - (age / rollingWindowSeconds))
                                        let nonCachedIn = max(0, inp - cache)
                                        let stepUnits = (Double(nonCachedIn) * 0.1) + Double(out)
                                        rollingWeightedUnits += stepUnits * decayFactor
                                    }

                                    if date >= cycleStart {
                                        conversationHadActivity = true
                                        totalInput += inp
                                        totalOutput += out
                                        totalCache += cache

                                        let stepCost = (Double(inp) * 0.0000005) + (Double(out) * 0.000002)
                                        let dayKey = dayKeyFormatter.string(from: date)
                                        dailyCosts[dayKey, default: 0.0] += stepCost
                                    }
                                }
                            }
                        }
                    }

                    if conversationHadActivity {
                        activeConversations += 1
                    }
                }
            } catch {
                // Ignore directory scan errors
            }
        }

        let totalCost = (Double(totalInput) * 0.0000005) + (Double(totalOutput) * 0.000002)

        // If we have real live quota groups from Antigravity language_server, use them!
        if !liveGroups.isEmpty && !isEnt {
            let geminiGroup = liveGroups.first { $0.name.lowercased().contains("gemini") && !$0.name.lowercased().contains("argon") }
            let claudeGroup = liveGroups.first { $0.name.lowercased().contains("claude") }
            let argonGroup = liveGroups.first { $0.name.lowercased().contains("argon") }

            let gemPct = Int((geminiGroup?.fiveHourRemaining ?? geminiGroup?.weeklyRemaining ?? 100.0).rounded())
            let argPct = Int((argonGroup?.weeklyRemaining ?? 100.0).rounded())
            let claude5h = Int((claudeGroup?.fiveHourRemaining ?? 0.0).rounded())
            let claude7d = Int((claudeGroup?.weeklyRemaining ?? 0.0).rounded())

            let primaryText = "Gemini \(gemPct)% • Argon \(argPct)%"
            let secondaryText = "Claude/GPT: \(claude5h)% (5h) • \(claude7d)% (7d)"
            let status = "Gemini: \(Int((geminiGroup?.weeklyRemaining ?? 100).rounded()))% (7d) / \(gemPct)% (5h) • Argon: \(argPct)%"

            // Main progress bar shows Gemini / Argon remaining percentage
            let mainRemaining = Double(min(gemPct, argPct))
            let usedPct = max(0.0, min(100.0, 100.0 - mainRemaining))

            return AntigravityResult(
                cost: 0.0,
                inputTokens: totalInput,
                outputTokens: totalOutput,
                cacheReadTokens: totalCache,
                conversationCount: activeConversations,
                rollingQuotaUsedPercent: usedPct,
                quotaGroups: liveGroups,
                quotaPrimaryText: primaryText,
                quotaSecondaryText: secondaryText,
                dailyCosts: [:],
                statusText: status,
                isConfigured: true
            )
        }

        let rollingCapacity: Double = 750_000.0
        let rollingUsedPct = min(100.0, max(0.0, (rollingWeightedUnits / rollingCapacity) * 100.0))

        let formattedTokens = formatTokens(totalInput + totalOutput)
        let status = isEnt
            ? "Cycle starting on \(config.antigravityBillingResetDay) • \(activeConversations) sessions • \(formattedTokens) tokens"
            : "Quota-based plan • \(activeConversations) active session\(activeConversations > 1 ? "s" : "") (5h)"

        return AntigravityResult(
            cost: isEnt ? totalCost : 0.0,
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheReadTokens: totalCache,
            conversationCount: activeConversations,
            rollingQuotaUsedPercent: rollingUsedPct,
            quotaGroups: liveGroups,
            quotaPrimaryText: nil,
            quotaSecondaryText: nil,
            dailyCosts: isEnt ? dailyCosts : [:],
            statusText: status,
            isConfigured: true
        )
    }

    // MARK: - Live Antigravity Language Server Quota Fetcher
    private func fetchLiveQuotaGroups() async -> [QuotaGroup]? {
        guard let serverInfo = findRunningLanguageServer() else {
            return nil
        }

        for port in serverInfo.ports {
            guard let url = URL(string: "http://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 2.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.setValue(serverInfo.csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
            request.httpBody = Data("{}".utf8)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                    continue
                }
                if let groups = parseQuotaSummaryJSON(data) {
                    return groups
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func findRunningLanguageServer() -> (csrfToken: String, ports: [Int])? {
        let psOut = runCommand("/bin/ps", arguments: ["aux"])
        for line in psOut.components(separatedBy: "\n") {
            guard line.contains("language_server"), line.contains("--csrf_token") else { continue }
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count > 1 else { continue }
            let pid = String(parts[1])

            // Extract csrf_token
            guard let range = line.range(of: "--csrf_token\\s+([a-fA-F0-9-]+)", options: .regularExpression) else {
                continue
            }
            let matchStr = String(line[range])
            let csrf = matchStr.replacingOccurrences(of: "--csrf_token", with: "").trimmingCharacters(in: .whitespaces)

            // Find listening TCP ports for this PID
            let lsofOut = runCommand("/usr/sbin/lsof", arguments: ["-nP", "-a", "-p", pid, "-iTCP", "-sTCP:LISTEN"])
            var ports: [Int] = []
            for lsofLine in lsofOut.components(separatedBy: "\n") {
                if let portRange = lsofLine.range(of: "127\\.0\\.0\\.1:(\\d+)", options: .regularExpression) {
                    let hostPort = String(lsofLine[portRange])
                    if let portStr = hostPort.components(separatedBy: ":").last, let port = Int(portStr) {
                        if !ports.contains(port) {
                            ports.append(port)
                        }
                    }
                }
            }

            if !csrf.isEmpty && !ports.isEmpty {
                return (csrf, ports)
            }
        }
        return nil
    }

    private func parseQuotaSummaryJSON(_ data: Data) -> [QuotaGroup]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = root["response"] as? [String: Any],
              let rawGroups = response["groups"] as? [[String: Any]] else {
            return nil
        }

        var result: [QuotaGroup] = []
        for g in rawGroups {
            let rawName = (g["displayName"] as? String) ?? "Models"
            let cleanName: String
            if rawName.lowercased().contains("gemini models") {
                cleanName = "Gemini"
            } else if rawName.lowercased().contains("claude") {
                cleanName = "Claude & GPT"
            } else {
                cleanName = rawName
            }

            let buckets = (g["buckets"] as? [[String: Any]]) ?? []
            var weeklyPct: Double? = nil
            var weeklyReset: String? = nil
            var fiveHourPct: Double? = nil
            var fiveHourReset: String? = nil

            for b in buckets {
                let window = (b["window"] as? String) ?? ""
                let frac = (b["remainingFraction"] as? Double) ?? Double((b["remainingFraction"] as? Int) ?? 0)
                let pct = (frac * 100.0).rounded()
                let resetTimeStr = b["resetTime"] as? String
                let resetCountdown = formatResetTime(resetTimeStr)

                if window == "weekly" {
                    weeklyPct = pct
                    weeklyReset = resetCountdown
                } else if window == "5h" {
                    fiveHourPct = pct
                    fiveHourReset = resetCountdown
                }
            }

            result.append(QuotaGroup(
                name: cleanName,
                weeklyRemaining: weeklyPct,
                weeklyResetText: weeklyReset,
                fiveHourRemaining: fiveHourPct,
                fiveHourResetText: fiveHourReset
            ))
        }

        return result.isEmpty ? nil : result
    }

    private func formatResetTime(_ isoString: String?) -> String? {
        guard let isoString = isoString else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        guard let resetDate = iso.date(from: isoString) ?? fallback.date(from: isoString) else {
            return nil
        }

        let diff = max(0, Int(resetDate.timeIntervalSinceNow))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func runCommand(_ path: String, arguments: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func saveCachedQuotaGroups(_ groups: [QuotaGroup]) {
        try? FileManager.default.createDirectory(at: AppConfig.configDirectoryURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(groups) {
            try? data.write(to: quotaCacheURL, options: .atomic)
        }
    }

    private static func loadCachedQuotaGroups() -> [QuotaGroup]? {
        guard let data = try? Data(contentsOf: quotaCacheURL) else { return nil }
        return try? JSONDecoder().decode([QuotaGroup].self, from: data)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}
