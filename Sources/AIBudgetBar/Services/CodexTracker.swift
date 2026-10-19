import Foundation

/// Reads quota metadata only. Local token counts are not an account billing total.
public final class CodexTracker {
    public init() {}

    public func fetchUsage(config: AppConfig) async -> ServiceUsage {
        guard config.isEnabled(service: .codex) else {
            return ServiceUsage(service: .codex, statusText: "Disabled")
        }
        if config.isEnterprise(service: .codex) {
            let spend = config.codexManualSpend
            return ServiceUsage(
                service: .codex, cost: max(0, spend ?? 0), budgetLimit: config.budgetFor(service: .codex),
                statusText: spend == nil ? "Enter your cycle spend in Preferences" : "Manually entered cycle spend",
                statusDetails: BillingCycle.resetLabel(resetDay: config.codexBillingResetDay),
                isConfigured: spend != nil, isOrgManaged: true, orgBadge: "🏢 Enterprise"
            )
        }

        let home = Self.homeURL(configuredPath: config.codexHomePath)
        return await Task.detached(priority: .utility) {
            Self.readUsage(home: home, budget: config.budgetFor(service: .codex))
        }.value
    }

    static func homeURL(configuredPath: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        let custom = configuredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = custom.isEmpty ? (environment["CODEX_HOME"] ?? "") : custom
        if path == "~" { return AppConfig.realHomeDirectory }
        if path.hasPrefix("~/") { return AppConfig.realHomeDirectory.appendingPathComponent(String(path.dropFirst(2))) }
        if !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return AppConfig.realHomeDirectory.appendingPathComponent(".codex")
    }

    struct Window: Decodable {
        let usedPercent: Double
        let windowMinutes: Int?
        let resetsAt: Double?

        func remaining(now: Date) -> Double? {
            // An expired snapshot cannot tell us the new window's actual usage.
            guard usedPercent.isFinite, let reset = resetsAt, reset > now.timeIntervalSince1970 else { return nil }
            return 100 - min(100, max(0, usedPercent))
        }
    }

    struct Snapshot: Decodable {
        let limitId: String?
        let primary: Window?
        let secondary: Window?
    }

    private struct Event: Decodable {
        let timestamp: String
        let type: String
        let payload: Payload

        struct Payload: Decodable {
            let type: String
            let rateLimits: Snapshot?
        }
    }

    static func readUsage(home: URL, budget: Double, now: Date = Date()) -> ServiceUsage {
        let cutoff = now.addingTimeInterval(-7 * 24 * 3600)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        var files: [(url: URL, modified: Date)] = []
        for directory in ["sessions", "archived_sessions"] {
            guard let enumerator = FileManager.default.enumerator(
                at: home.appendingPathComponent(directory), includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                      let modified = values.contentModificationDate, modified >= cutoff else { continue }
                files.append((url, modified))
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackISO = ISO8601DateFormatter()
        var latest: (date: Date, snapshot: Snapshot)?

        // Bound work on refresh: at most 64 recent files, 512 KiB per file.
        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(64) {
            guard let data = tail(of: file.url) else { continue }
            for line in data.split(separator: 0x0A) {
                guard let event = try? decoder.decode(Event.self, from: Data(line)),
                      event.type == "event_msg", event.payload.type == "token_count",
                      let snapshot = event.payload.rateLimits,
                      snapshot.limitId == nil || snapshot.limitId == "codex",
                      snapshot.primary != nil || snapshot.secondary != nil,
                      let date = iso.date(from: event.timestamp) ?? fallbackISO.date(from: event.timestamp),
                      date >= cutoff, date <= now,
                      latest == nil || date > latest!.date else { continue }
                latest = (date, snapshot)
            }
        }

        var usage = ServiceUsage(service: .codex, budgetLimit: budget,
                                 statusText: "Run Codex locally to record a quota snapshot",
                                 statusDetails: "Local Codex sessions • No API key required",
                                 orgBadge: "👤 Plan", isQuotaMode: true,
                                 quotaPrimaryText: "Unavailable", quotaSecondaryText: "No recent quota snapshot")
        guard let latest else { return usage }
        let windows = [latest.snapshot.primary, latest.snapshot.secondary].compactMap { $0 }
        let fiveHour = windows.first { $0.windowMinutes == 300 }
        let weekly = windows.first { $0.windowMinutes == 10080 }
        let fiveRemaining = fiveHour?.remaining(now: now)
        let weeklyRemaining = weekly?.remaining(now: now)
        guard fiveRemaining != nil || weeklyRemaining != nil else {
            usage.statusText = "Quota snapshot expired or unsupported; run Codex to update"
            return usage
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        func resetText(_ window: Window?) -> String? {
            guard let reset = window?.resetsAt, reset > now.timeIntervalSince1970 else { return nil }
            return formatter.string(from: Date(timeIntervalSince1970: reset))
        }
        var labels: [String] = []
        if let remaining = fiveRemaining { labels.append(String(format: "5h: %.0f%%", remaining)) }
        if let remaining = weeklyRemaining { labels.append(String(format: "7d: %.0f%%", remaining)) }
        usage.isConfigured = true
        usage.statusText = labels.joined(separator: " • ") + " remaining"
        usage.statusDetails = "Local snapshot • " + formatter.string(from: latest.date)
        usage.quotaPrimaryText = usage.statusText
        usage.quotaSecondaryText = "Recorded by Codex on this Mac"
        usage.quotaPercent = 100 - ([fiveRemaining, weeklyRemaining].compactMap { $0 }.min() ?? 0)
        usage.quotaGroups = [QuotaGroup(name: "Codex", weeklyRemaining: weeklyRemaining,
                                       weeklyResetText: resetText(weekly), fiveHourRemaining: fiveRemaining,
                                       fiveHourResetText: resetText(fiveHour))]
        usage.lastUpdated = latest.date
        return usage
    }

    private static func tail(of url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            let size = try handle.seekToEnd()
            let offset = size > 524288 ? size - 524288 : 0
            try handle.seek(toOffset: offset)
            guard var data = try handle.read(upToCount: 524288) else { return nil }
            // Drop the first incomplete JSON record when reading a suffix.
            if offset > 0 {
                guard let newline = data.firstIndex(of: 0x0A) else { return nil }
                data = Data(data.suffix(from: data.index(after: newline)))
            }
            return data
        } catch { return nil }
    }
}
