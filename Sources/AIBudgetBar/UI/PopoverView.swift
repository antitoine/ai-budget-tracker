import SwiftUI
import AppKit

public struct PopoverView: View {
    @ObservedObject var manager: BudgetManager
    var onOpenPreferences: () -> Void

    public init(manager: BudgetManager, onOpenPreferences: @escaping () -> Void) {
        self.manager = manager
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
            // MARK: - Header
            VStack(spacing: 10) {
                // Top status bar in popover
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(progressColor)
                        Text("AI Budget Bar")
                            .font(.system(size: 12, weight: .bold))
                    }

                    Spacer()

                    Text(summary.monthName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Big Total Numbers
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", summary.totalCost))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(summary.isOverBudget ? .red : .primary)

                    Text(config.currency)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Budget: \(String(format: "%.0f %@", summary.totalBudget, config.currency))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("Left: \(String(format: "%.2f %@", summary.remainingBudget, config.currency))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(summary.remainingBudget > 0 ? .green : .red)
                    }
                }

                // Global Progress Bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 7)

                            let clamped = min(max(summary.percentUsed / 100.0, 0.0), 1.0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [progressColor.opacity(0.85), progressColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(clamped), height: 7)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(String(format: "%.1f%% of budget used", summary.percentUsed))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(summary.isOverBudget ? .red : (summary.isWarning ? .orange : .secondary))

                        Spacer()

                        if config.demoMode {
                            Text("DEMO MODE")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(3)
                        }
                    }
                }

                // Warning Banner if needed
                if summary.isOverBudget {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 11))
                        Text("Monthly limit exceeded!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.12)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            // MARK: - Services List & History Chart
            ScrollView {
                VStack(spacing: 10) {
                    if config.activeServices.isEmpty {
                        Text("No AI services enabled. Enable a service in Preferences.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(summary.services) { sUsage in
                        ServiceRowView(usage: sUsage, currency: config.currency)
                    }

                    // 7-day sparkline
                    HistoryChartView(dailyPoints: summary.dailyHistory, currency: config.currency, services: config.activeServices)
                }
                .padding(14)
            }
            .frame(height: 310)

            Divider()

            // MARK: - Footer Actions
            HStack {
                // Refresh button
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

                // Preferences button
                Button(action: {
                    onOpenPreferences()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Preferences and API keys")

                // Quit button
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit AI Budget Bar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
}

// Visual Effect helper for translucent macOS vibrancy
public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
