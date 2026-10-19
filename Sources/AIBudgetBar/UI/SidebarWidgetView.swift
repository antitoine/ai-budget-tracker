import SwiftUI
import AppKit

public struct SidebarWidgetView: View {
    @ObservedObject var manager: BudgetManager
    var onClose: () -> Void
    var onOpenPreferences: () -> Void

    public init(manager: BudgetManager, onClose: @escaping () -> Void, onOpenPreferences: @escaping () -> Void) {
        self.manager = manager
        self.onClose = onClose
        self.onOpenPreferences = onOpenPreferences
    }

    private var summary: BudgetSummary {
        manager.summary
    }

    private var config: AppConfig {
        manager.config
    }

    private var progressColor: Color {
        if summary.isOverBudget {
            return .red
        } else if summary.isWarning {
            return .orange
        } else {
            return Color(red: 0.20, green: 0.65, blue: 0.95)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Widget Window Bar / Drag Handle
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(progressColor)
                    Text("AI Budget Widget")
                        .font(.system(size: 12, weight: .bold))
                }

                Spacer()

                Button(action: onOpenPreferences) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Preferences")

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close widget")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Main Content
            VStack(spacing: 12) {
                // Header Spend Figures
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.2f %@", summary.totalCost, config.currency))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(summary.isOverBudget ? .red : .primary)

                        Text("of \(String(format: "%.0f %@", summary.totalBudget, config.currency)) budget")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(summary.monthName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("Left: \(String(format: "%.2f %@", summary.remainingBudget, config.currency))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(summary.remainingBudget > 0 ? .green : .red)
                    }
                }

                // Global Progress Bar
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 7)

                            let clamped = min(max(summary.percentUsed / 100.0, 0.0), 1.0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [progressColor.opacity(0.8), progressColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(clamped), height: 7)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(String(format: "%.1f%% consumed", summary.percentUsed))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(summary.isOverBudget ? .red : (summary.isWarning ? .orange : .secondary))
                        Spacer()
                    }
                }

                // 3 Service Rows
                VStack(spacing: 8) {
                    ForEach(summary.services) { s in
                        ServiceRowView(usage: s, currency: config.currency)
                    }
                }

                // 7-day sparkline
                HistoryChartView(dailyPoints: summary.dailyHistory, currency: config.currency)
            }
            .padding(14)

            Divider()

            // Footer
            HStack {
                Button(action: {
                    Task {
                        await manager.refreshAll()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(manager.isRefreshing ? 360 : 0))
                            .animation(manager.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isRefreshing)
                        Text(manager.isRefreshing ? "Refreshing..." : "Refresh")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .disabled(manager.isRefreshing)

                Spacer()

                Text("Docked to right of screen")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: -5, y: 5)
    }
}
