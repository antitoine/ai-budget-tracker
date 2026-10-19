import SwiftUI

public struct HistoryChartView: View {
    public let dailyPoints: [DailyPoint]
    public let currency: String

    @State private var hoveredPoint: DailyPoint? = nil

    public init(dailyPoints: [DailyPoint], currency: String) {
        self.dailyPoints = dailyPoints
        self.currency = currency
    }

    private var maxCost: Double {
        let maxDaily = dailyPoints.map { $0.totalCost }.max() ?? 1.0
        return max(maxDaily, 2.0)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Évolution (7 jours)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let hovered = hoveredPoint {
                    Text("\(hovered.dayLabel): \(String(format: "%.2f %@", hovered.totalCost, currency))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                } else {
                    HStack(spacing: 6) {
                        legendDot(color: AIService.cursor.brandColor, label: "Cursor")
                        legendDot(color: AIService.antigravity.brandColor, label: "Antigravity")
                        legendDot(color: AIService.claude.brandColor, label: "Claude")
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }

            // Bars
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(dailyPoints) { point in
                    VStack(spacing: 4) {
                        // Stacked bar
                        GeometryReader { geo in
                            let height = geo.size.height
                            let cursorHeight = CGFloat(point.cursorCost / maxCost) * height
                            let agyHeight = CGFloat(point.antigravityCost / maxCost) * height
                            let claudeHeight = CGFloat(point.claudeCost / maxCost) * height

                            VStack(spacing: 1) {
                                Spacer(minLength: 0)

                                if claudeHeight > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AIService.claude.brandColor)
                                        .frame(height: max(2, claudeHeight))
                                }

                                if agyHeight > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AIService.antigravity.brandColor)
                                        .frame(height: max(2, agyHeight))
                                }

                                if cursorHeight > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AIService.cursor.brandColor)
                                        .frame(height: max(2, cursorHeight))
                                }

                                if point.totalCost == 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 3)
                                }
                            }
                        }
                        .frame(height: 54)
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            hoveredPoint = isHovered ? point : nil
                        }

                        // Day label
                        Text(point.dayLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 72)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}
