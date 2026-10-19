import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Background Refresh AppIntent (keeps Notification Center open!)
@available(macOS 14.0, *)
struct RefreshBudgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Budgets"
    static var description = IntentDescription("Refreshes usage and quotas without closing the widget bar.")

    func perform() async throws -> some IntentResult {
        let configDir = AppConfig.configDirectoryURL
        let cacheURL = configDir.appendingPathComponent("cache.json")
        let triggerURL = configDir.appendingPathComponent("refresh.trigger")

        let initialModDate = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date) ?? .distantPast

        // 1. Write trigger file for sandboxed IPC
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        try? Data("1".utf8).write(to: triggerURL, options: .atomic)

        // 2. Also post DistributedNotification
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.antigravity.aibudgetbar.refresh"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        // 3. Wait up to 2.4s for AIBudgetBar to update cache.json
        for _ in 0..<8 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let newModDate = try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date,
               newModDate > initialModDate {
                break
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline Provider
struct BudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), summary: sampleSummary(), currency: "$")
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        let cfg = AppConfig.load()
        let summary = (loadSummary() ?? BudgetSummary()).applying(config: cfg)
        completion(BudgetEntry(date: Date(), summary: summary, currency: cfg.currency))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let cfg = AppConfig.load()
        let summary = (loadSummary() ?? BudgetSummary()).applying(config: cfg)
        let entry = BudgetEntry(date: Date(), summary: summary, currency: cfg.currency)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadSummary() -> BudgetSummary? {
        let cacheURL = AppConfig.configDirectoryURL.appendingPathComponent("cache.json")
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(BudgetSummary.self, from: data)
    }

    private func sampleSummary() -> BudgetSummary {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"

        let cUsage = ServiceUsage(
            service: .cursor,
            cost: 21.60,
            budgetLimit: 30.0,
            requestCount: 265,
            requestLimit: 500,
            statusText: "265/500 requests",
            isConfigured: true
        )

        let aUsage = ServiceUsage(
            service: .antigravity,
            cost: 0.0,
            budgetLimit: 35.0,
            statusText: "Gemini: 96% (7d) / 97% (5h)",
            isConfigured: true,
            isQuotaMode: true,
            quotaPrimaryText: "Gemini 97% • Argon 71%",
            quotaSecondaryText: "Claude/GPT: 0% (5h) • 49% (7d)",
            quotaPercent: 29.0,
            quotaGroups: [
                QuotaGroup(name: "Gemini", weeklyRemaining: 96, weeklyResetText: "6d 17h", fiveHourRemaining: 97, fiveHourResetText: "3h 19m"),
                QuotaGroup(name: "Claude & GPT", weeklyRemaining: 49, weeklyResetText: "6d 22h", fiveHourRemaining: 0, fiveHourResetText: "3h 55m"),
                QuotaGroup(name: "Gemini 4 Argon", weeklyRemaining: 71, weeklyResetText: "6d 17h")
            ]
        )

        let clUsage = ServiceUsage(
            service: .claude,
            cost: 14.80,
            budgetLimit: 35.0,
            inputTokens: 210_000,
            outputTokens: 38_000,
            statusText: "Sonnet 3.5 & 3.7",
            isConfigured: true
        )

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.locale = Locale(identifier: "en_US")

        let daily: [DailyPoint] = (0..<7).reversed().compactMap { i in
            guard let d = calendar.date(byAdding: .day, value: -i, to: today) else { return nil }
            return DailyPoint(
                dateString: "\(i)",
                dayLabel: dayFormatter.string(from: d).capitalized,
                cursorCost: Double.random(in: 0.5...2.0),
                antigravityCost: Double.random(in: 0.5...1.5),
                claudeCost: Double.random(in: 0.8...2.5)
            )
        }

        return BudgetSummary(
            totalCost: 36.40,
            totalBudget: 100.0,
            monthName: formatter.string(from: today).capitalized,
            services: [cUsage, aUsage, clUsage],
            dailyHistory: daily,
            lastRefreshed: Date()
        )
    }
}

// MARK: - Timeline Entry
struct BudgetEntry: TimelineEntry {
    let date: Date
    let summary: BudgetSummary
    let currency: String
}

// MARK: - Medium Widget View
struct MediumBudgetWidgetView: View {
    let summary: BudgetSummary
    let currency: String

    var body: some View {
        HStack(spacing: 10) {
            // Left Column: Total Spend, Gauge & Actions
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 10, weight: .bold))
                    Text("AI Budget")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    // Refresh via AppIntent (does NOT close Notification Center!)
                    Button(intent: RefreshBudgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    // Open Floating Window
                    Link(destination: URL(string: "aibudgetbar://floating")!) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    // Open Preferences
                    Link(destination: URL(string: "aibudgetbar://preferences")!) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f %@", summary.totalCost, currency))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(summary.isOverBudget ? .red : .primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text("of \(String(format: "%.0f %@", summary.totalBudget, currency))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 5)

                        let percent = min(max(summary.percentUsed / 100.0, 0.0), 1.0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(summary.isOverBudget ? Color.red : (summary.isWarning ? Color.orange : Color.blue))
                            .frame(width: geo.size.width * CGFloat(percent), height: 5)
                    }
                }
                .frame(height: 5)

                Text(String(format: "%.1f%% consumed", summary.percentUsed))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(summary.isOverBudget ? .red : (summary.isWarning ? .orange : .secondary))
            }
            .frame(width: 118)

            Divider()

            // Right Column: Clickable Service Mini Cards
            VStack(spacing: 5) {
                if summary.services.isEmpty {
                    Text("Enable an AI service in Preferences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(summary.services) { s in
                    Link(destination: s.service.widgetDeepLinkURL) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Image(systemName: s.service.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(s.service.brandColor)
                                    .frame(width: 13)

                                Text(s.service.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)

                                Spacer(minLength: 4)

                                if s.isQuotaMode {
                                    Text(s.quotaPrimaryText ?? String(format: "%.0f%% remaining", s.remainingPercent))
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(s.isOverBudget ? .red : (s.isWarning ? .orange : s.service.brandColor))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                } else {
                                    Text(String(format: "%.2f %@", s.cost, currency))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(s.isOverBudget ? .red : .primary)
                                        .lineLimit(1)

                                    Text("/ \(String(format: "%.0f", s.budgetLimit))")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }

                            if s.isQuotaMode, let secondary = s.quotaSecondaryText, !s.quotaGroups.isEmpty {
                                Text(secondary)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .padding(.leading, 18)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Large Widget View
struct LargeBudgetWidgetView: View {
    let summary: BudgetSummary
    let currency: String

    var body: some View {
        VStack(spacing: 9) {
            // Header with Refresh (in-place AppIntent), Floating Window & Preferences buttons
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .bold))
                    Text("AI Budget")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                // Refresh button via AppIntent (does NOT close Notification Center!)
                Button(intent: RefreshBudgetIntent()) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.14)))
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Open Floating Window button
                Link(destination: URL(string: "aibudgetbar://floating")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "macwindow.on.rectangle")
                        Text("Window")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.14)))
                    .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                // Preferences button
                Link(destination: URL(string: "aibudgetbar://preferences")!) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(4.5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.14)))
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Big Total Spend
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f %@", summary.totalCost, currency))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(summary.isOverBudget ? .red : .primary)
                    Text(summary.monthName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Budget: \(String(format: "%.0f %@", summary.totalBudget, currency))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Left: \(String(format: "%.2f %@", summary.remainingBudget, currency))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(summary.remainingBudget > 0 ? .green : .red)
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)

                    let percent = min(max(summary.percentUsed / 100.0, 0.0), 1.0)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(summary.isOverBudget ? Color.red : (summary.isWarning ? Color.orange : Color.blue))
                        .frame(width: geo.size.width * CGFloat(percent), height: 6)
                }
            }
            .frame(height: 6)

            // Clickable Services
            VStack(spacing: 7) {
                if summary.services.isEmpty {
                    Text("Enable an AI service in Preferences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(summary.services) { s in
                    Link(destination: s.service.widgetDeepLinkURL) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(s.service.brandColor.opacity(0.16))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: s.service.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(s.service.brandColor)
                                }

                                VStack(alignment: .leading, spacing: 1.5) {
                                    HStack(spacing: 5) {
                                        Text(s.service.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)

                                        if let badge = s.orgBadge {
                                            let badgeColor: Color = s.isQuotaMode ? .purple : .green
                                            Text(badge)
                                                .font(.system(size: 8, weight: .semibold))
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(badgeColor.opacity(0.18))
                                                .foregroundColor(badgeColor)
                                                .cornerRadius(4)
                                        }
                                    }

                                    if !s.isQuotaMode || s.quotaGroups.isEmpty || summary.services.count > 3 {
                                        Text(s.statusText)
                                            .font(.system(size: 9.5))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                    }
                                }

                                Spacer(minLength: 4)

                                // Only show right-hand summary when there is no multi-row quota table below
                                if !s.isQuotaMode || s.quotaGroups.isEmpty || summary.services.count > 3 {
                                    VStack(alignment: .trailing, spacing: 1.5) {
                                        if s.isQuotaMode {
                                            Text(s.quotaPrimaryText ?? String(format: "%.0f%% remaining", s.remainingPercent))
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundColor(s.isOverBudget ? .red : (s.isWarning ? .orange : s.service.brandColor))
                                                .lineLimit(1)
                                            Text(s.quotaSecondaryText ?? "Available quota")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        } else {
                                            Text(String(format: "%.2f %@", s.cost, currency))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(s.isOverBudget ? .red : .primary)
                                                .lineLimit(1)
                                            Text("Max \(String(format: "%.0f %@", s.budgetLimit, currency))")
                                                .font(.system(size: 9.5))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                } else {
                                    Text("Real-time")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            // Real per-model quota breakdown for Antigravity
                            if s.isQuotaMode && !s.quotaGroups.isEmpty && summary.services.count <= 3 {
                                Divider()
                                    .opacity(0.4)

                                VStack(spacing: 4) {
                                    ForEach(s.quotaGroups) { grp in
                                        HStack(spacing: 6) {
                                            Text(grp.name)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(.primary.opacity(0.9))
                                                .frame(width: 96, alignment: .leading)
                                                .lineLimit(1)

                                            if let w = grp.weeklyRemaining {
                                                HStack(spacing: 3) {
                                                    Text("Weekly:")
                                                        .font(.system(size: 9.5))
                                                        .foregroundColor(.secondary)
                                                    Text("\(Int(w.rounded()))%")
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundColor(w <= 10 ? .red : (w <= 25 ? .orange : .green))
                                                }
                                            }

                                            Spacer()

                                            if let fh = grp.fiveHourRemaining {
                                                HStack(spacing: 3) {
                                                    Text("5h:")
                                                        .font(.system(size: 9.5))
                                                        .foregroundColor(.secondary)
                                                    Text("\(Int(fh.rounded()))%")
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundColor(fh <= 10 ? .red : (fh <= 25 ? .orange : s.service.brandColor))
                                                }
                                            } else if let r = grp.weeklyResetText {
                                                Text("Reset \(r)")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.09)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(4)
    }
}

// MARK: - Widget Entry View
struct AIBudgetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: BudgetTimelineProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                LargeBudgetWidgetView(summary: entry.summary, currency: entry.currency)
            default:
                MediumBudgetWidgetView(summary: entry.summary, currency: entry.currency)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Definition
@main
struct AIBudgetWidget: Widget {
    let kind: String = "AIBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            AIBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AI Budget Tracker")
        .description("Track your Cursor, Antigravity, Claude, and Codex spend and quotas.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
