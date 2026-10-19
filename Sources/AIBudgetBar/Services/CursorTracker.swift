import Foundation

/// Fetches Cursor team usage by calling the same CSV export endpoint the dashboard
/// (and `cursor_usage_total.py`) uses, then sums the "Cost" column for the current cycle.
public final class CursorTracker {
    public init() {}

    public struct CursorResult {
        public let cost: Double
        public let requestCount: Int
        public let requestLimit: Int?
        public let dailyCosts: [String: Double]
        public let statusText: String
        public let isConfigured: Bool
        public let isOrgManaged: Bool
        public let orgBadge: String?
        public let isError: Bool
    }

    /// The export endpoint is slow (≈40 s observed), so use a generous timeout.
    private static let exportTimeout: TimeInterval = 120

    public func fetchUsage(config: AppConfig) async -> CursorResult {
        let token = config.cursorSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return CursorResult(
                cost: 0, requestCount: 0, requestLimit: nil, dailyCosts: [:],
                statusText: "WorkosCursorSessionToken cookie required",
                isConfigured: false, isOrgManaged: false, orgBadge: nil, isError: false
            )
        }
        return await fetchViaCsvExport(config: config, token: token)
    }

    private func fetchViaCsvExport(config: AppConfig, token: String) async -> CursorResult {
        let teamId = extractTeamId(from: token) ?? config.cursorTeamId
        let cycle = BillingCycle.period(resetDay: config.cursorBillingResetDay)

        // Same window as the Python script: cycle start 00:00 UTC -> end of today UTC.
        let cal = BillingCycle.utcCalendar
        let endOfToday = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: Date())) ?? Date()

        let startMs = Int64(cycle.start.timeIntervalSince1970 * 1000)
        let endMs = Int64(endOfToday.timeIntervalSince1970 * 1000)

        let urlString = "https://cursor.com/api/dashboard/export-usage-events-csv"
            + "?teamId=\(teamId)&isEnterprise=false&startDate=\(startMs)&endDate=\(endMs)&strategy=tokens"
        guard let url = URL(string: urlString) else {
            return errorResult("Invalid export URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.exportTimeout
        request.setValue("WorkosCursorSessionToken=\(token)", forHTTPHeaderField: "Cookie")
        request.setValue("text/csv", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if status == 401 || status == 403 {
                return errorResult("Cursor cookie expired (\(status))")
            }
            guard (200...299).contains(status), let csvText = String(data: data, encoding: .utf8) else {
                return errorResult("Cursor export unavailable (\(status))")
            }
            guard let parsed = Self.sumCosts(csv: csvText) else {
                return errorResult("Unexpected CSV format")
            }

            return CursorResult(
                cost: parsed.total,
                requestCount: parsed.count,
                requestLimit: nil,
                dailyCosts: parsed.daily,
                statusText: "\(parsed.count) requests this cycle",
                isConfigured: true,
                isOrgManaged: true,
                orgBadge: "Team",
                isError: false
            )
        } catch {
            return errorResult("Network: \(error.localizedDescription)")
        }
    }

    // MARK: - CSV

    /// Sums the "Cost" column ("-" / "Free" count as 0) and groups costs per local day.
    static func sumCosts(csv: String) -> (total: Double, count: Int, daily: [String: Double])? {
        let rows = parseCSV(csv)
        guard let header = rows.first,
              let costIdx = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "Cost" }) else {
            return nil
        }
        let dateIdx = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "Date" })

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        let dayKey = DateFormatter()
        dayKey.dateFormat = "yyyy-MM-dd"

        var total = 0.0
        var count = 0
        var daily: [String: Double] = [:]

        for row in rows.dropFirst() where row.count > costIdx {
            if row.count == 1 && row[0].isEmpty { continue }
            count += 1
            let raw = row[costIdx].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "$", with: "")
            guard let value = Double(raw) else { continue }
            total += value

            if let dateIdx, row.count > dateIdx {
                let ds = row[dateIdx].trimmingCharacters(in: .whitespaces)
                if let d = iso.date(from: ds) ?? isoNoFrac.date(from: ds) {
                    daily[dayKey.string(from: d), default: 0] += value
                }
            }
        }
        return (total, count, daily)
    }

    /// Minimal RFC 4180 parser (handles quoted fields, embedded commas, escaped quotes, CRLF).
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        let scalars = Array(text.unicodeScalars)
        var i = 0

        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count && scalars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(String(field))
                    field = String.UnicodeScalarView()
                case "\r", "\n":
                    if c == "\r" && i + 1 < scalars.count && scalars[i + 1] == "\n" { i += 1 }
                    row.append(String(field))
                    field = String.UnicodeScalarView()
                    rows.append(row)
                    row = []
                default:
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }
        return rows
    }

    // MARK: - Helpers

    private func extractTeamId(from token: String) -> String? {
        let decoded = token.removingPercentEncoding ?? token
        let parts = decoded.components(separatedBy: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targeting = json["cursorTargeting"] as? [String: Any],
              let tid = targeting["teamId"] else {
            return nil
        }
        return "\(tid)"
    }

    private func errorResult(_ message: String) -> CursorResult {
        return CursorResult(
            cost: 0, requestCount: 0, requestLimit: nil, dailyCosts: [:],
            statusText: message,
            isConfigured: true, isOrgManaged: true, orgBadge: "Team", isError: true
        )
    }
}
