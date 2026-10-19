import SwiftUI
import AppKit

public struct ServiceRowView: View {
    public let usage: ServiceUsage
    public let currency: String
    @State private var isHovered: Bool = false

    public init(usage: ServiceUsage, currency: String) {
        self.usage = usage
        self.currency = currency
    }

    private var progressColor: Color {
        if usage.isOverBudget {
            return .red
        } else if usage.isWarning {
            return .orange
        } else {
            return usage.service.brandColor
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header Row
            HStack(spacing: 10) {
                // Service Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(usage.service.brandColor.opacity(0.18))
                        .frame(width: 28, height: 28)

                    Image(systemName: usage.service.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(usage.service.brandColor)
                }

                // Name & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(usage.service.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        if let badge = usage.orgBadge {
                            let badgeColor: Color = usage.isQuotaMode ? .purple : .green
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

                    Text(usage.isQuotaMode && !usage.quotaGroups.isEmpty ? usage.statusDetails : usage.statusText)
                        .font(.system(size: 10))
                        .foregroundColor(usage.isError ? .red : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 6)

                // Spent amount & limit OR Personal Quota Remaining % (only when no detailed group table is below)
                if !(usage.isQuotaMode && !usage.quotaGroups.isEmpty) {
                    VStack(alignment: .trailing, spacing: 1) {
                        if usage.isQuotaMode {
                            Text(usage.quotaPrimaryText ?? String(format: "%.0f%% remaining", usage.remainingPercent))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(usage.isOverBudget ? .red : (usage.isWarning ? .orange : usage.service.brandColor))
                                .lineLimit(1)

                            Text(usage.quotaSecondaryText ?? "Available quota")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            HStack(spacing: 2) {
                                Text(String(format: "%.2f", usage.cost))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(usage.isOverBudget ? .red : .primary)
                                Text(currency)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            Text("Max \(String(format: "%.0f %@", usage.budgetLimit, currency))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundColor(isHovered ? .primary : .secondary)
            }

            // Progress bar or detailed per-model quota groups
            if usage.isQuotaMode && usage.quotaPercent == nil {
                Text("Quota unavailable until a fresh reading is recorded")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else if usage.isQuotaMode && !usage.quotaGroups.isEmpty {
                VStack(spacing: 5) {
                    ForEach(usage.quotaGroups) { grp in
                        HStack(spacing: 6) {
                            Text(grp.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 92, alignment: .leading)
                                .lineLimit(1)

                            if let w = grp.weeklyRemaining {
                                HStack(spacing: 3) {
                                    Text("7d:")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f%%", w))
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(w <= 10 ? .red : (w <= 25 ? .orange : .green))
                                    if let r = grp.weeklyResetText {
                                        Text("(\(r))")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer(minLength: 4)

                            if let fh = grp.fiveHourRemaining {
                                HStack(spacing: 3) {
                                    Text("5h:")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f%%", fh))
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(fh <= 10 ? .red : (fh <= 25 ? .orange : usage.service.brandColor))
                                    if let r = grp.fiveHourResetText {
                                        Text("(\(r))")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
                    }
                }
            } else {
                // Standard Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 5)

                        let barFraction = usage.isQuotaMode
                            ? min(max(usage.remainingPercent / 100.0, 0.0), 1.0)
                            : min(max(usage.percentUsed / 100.0, 0.0), 1.0)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(progressColor)
                            .frame(width: geo.size.width * CGFloat(barFraction), height: 5)
                    }
                }
                .frame(height: 5)

                // Bottom details row
                HStack {
                    if usage.isQuotaMode {
                        Text(usage.statusDetails.isEmpty ? "Rolling window • Auto-refreshed" : usage.statusDetails)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(String(format: "%.0f%% available (%.0f%% used)", usage.remainingPercent, usage.percentUsed))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(usage.isOverBudget ? .red : (usage.isWarning ? .orange : .secondary))
                    } else {
                        if usage.inputTokens > 0 {
                            Text("Tokens: \(formatCompact(usage.inputTokens)) in / \(formatCompact(usage.outputTokens)) out")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else if !usage.statusDetails.isEmpty {
                            Text(usage.statusDetails)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else if usage.requestCount > 0 {
                            Text("\(usage.requestCount) events this cycle")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if usage.inputTokens > 0 && !usage.statusDetails.isEmpty {
                            Text("\(usage.statusDetails) •")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.1f%% consumed", usage.percentUsed))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(usage.isOverBudget ? .red : (usage.isWarning ? .orange : .secondary))
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.95 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(usage.isOverBudget ? Color.red.opacity(0.4) : (isHovered ? usage.service.brandColor.opacity(0.4) : Color.clear), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            NSWorkspace.shared.open(usage.service.dashboardURL)
        }
        .help("Click to open \(usage.service.displayName) usage page")
    }

    private func formatCompact(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1_000 {
            return String(format: "%.0fk", Double(number) / 1_000.0)
        } else {
            return "\(number)"
        }
    }
}
