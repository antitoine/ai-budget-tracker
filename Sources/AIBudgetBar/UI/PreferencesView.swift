import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var manager: BudgetManager
    @State private var config: AppConfig
    @State private var selectedTab: Int = 0
    @State private var saveStatusMessage: String? = nil

    public init(manager: BudgetManager) {
        self.manager = manager
        _config = State(initialValue: manager.config)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tabs Bar
            Picker("", selection: $selectedTab) {
                Text("Services & Cycles").tag(0)
                Text("Budget Limits").tag(1)
                Text("General").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == 0 {
                        servicesTab
                    } else if selectedTab == 1 {
                        budgetsTab
                    } else {
                        generalTab
                    }
                }
                .padding(20)
            }
            .frame(height: 400)

            Divider()

            // Footer
            HStack {
                if let msg = saveStatusMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }

                Spacer()

                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }

                Button("Save and Refresh") {
                    manager.updateConfig(config)
                    saveStatusMessage = "Configuration saved!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        saveStatusMessage = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 540, height: 520)
    }

    private func enterpriseBinding(for service: AIService) -> Binding<Bool> {
        Binding(
            get: { config.isEnterprise(service: service) },
            set: { config.setEnterprise($0, for: service) }
        )
    }

    // MARK: - Services Tab
    private var servicesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cursor Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: AIService.cursor.iconName)
                        .foregroundColor(AIService.cursor.brandColor)
                    Text("Cursor")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: enterpriseBinding(for: .cursor)) {
                        Text("🏢 Enterprise").tag(true)
                        Text("👤 Plan (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .cursor) {
                    HStack {
                        Text("Monthly billing cycle reset day:")
                            .font(.subheadline)
                        Spacer()
                        TextField("16", value: $config.cursorBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("of the month")
                            .font(.caption)
                    }
                }

                Text("Session cookie (WorkosCursorSessionToken):")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("Paste your WorkosCursorSessionToken", text: $config.cursorSessionToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("✓ Automatic synchronization via Cursor CSV export (Team #\(config.cursorTeamId)).")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))

            // Claude Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: AIService.claude.iconName)
                        .foregroundColor(AIService.claude.brandColor)
                    Text("Claude (Anthropic)")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: enterpriseBinding(for: .claude)) {
                        Text("🏢 Enterprise").tag(true)
                        Text("👤 Plan (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .claude) {
                    HStack {
                        Text("Monthly billing cycle reset day:")
                            .font(.subheadline)
                        Spacer()
                        TextField("1", value: $config.claudeBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("of the month")
                            .font(.caption)
                    }
                }

                Text("claude.ai sessionKey cookie (100% automatic synchronization):")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("sk-ant-sid02-...", text: $config.claudeSessionCookie)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !config.claudeSessionCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("✓ Automatic synchronization active with claude.ai/settings/usage.")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    HStack {
                        Text("Or fallback manual amount:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("0.00", value: Binding(
                            get: { config.claudeManualSpend ?? 0.0 },
                            set: { config.claudeManualSpend = $0 > 0 ? $0 : nil }
                        ), format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 90)
                        Text(config.currency)
                            .font(.caption)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))

            // Antigravity Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: AIService.antigravity.iconName)
                        .foregroundColor(AIService.antigravity.brandColor)
                    Text("Antigravity")
                        .font(.headline)
                    Spacer()
                    Picker("", selection: enterpriseBinding(for: .antigravity)) {
                        Text("🏢 Enterprise").tag(true)
                        Text("👤 Plan (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .antigravity) {
                    HStack {
                        Text("Monthly billing cycle reset day:")
                            .font(.subheadline)
                        Spacer()
                        TextField("18", value: $config.antigravityBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("of the month")
                            .font(.caption)
                    }
                }

                Toggle("Automatically scan local activity (~/.gemini/antigravity/brain)", isOn: $config.antigravityScanBrainDir)
                    .font(.caption)

                Text(config.isEnterprise(service: .antigravity)
                     ? "✓ Enterprise Mode: estimated cost included in global budget."
                     : "✓ Personal Plan Mode: displays only remaining quota % on a rolling window (no monthly cycle or $ amount).")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
        }
    }

    // MARK: - Budgets Tab (CHAMPS LIBRES SANS SLIDER)
    private var budgetsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Currency
            HStack {
                Text("Display currency:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $config.currency) {
                    Text("$ (USD)").tag("$")
                    Text("€ (EUR)").tag("€")
                    Text("£ (GBP)").tag("£")
                    Text("CHF").tag("CHF")
                }
                .frame(width: 120)
            }

            Divider()

            // Global Enterprise Monthly Budget (Free-form text field)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Global Monthly Enterprise Budget (custom field):")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    TextField("1500", value: $config.globalMonthlyBudget, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 110)
                        .font(.system(.body, design: .monospaced))
                    Text(config.currency)
                        .font(.caption)
                }
                Text("Global budget allocated by your company (in addition to per-tool max limits). Only tools marked \"🏢 Enterprise\" are counted in this total.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Per-Service Maximum Limits (only for Enterprise services)
            Text("Maximum limits per tool (🏢 Enterprise — custom fields):")
                .font(.subheadline)
                .fontWeight(.bold)

            if config.isEnterprise(service: .cursor) {
                freeBudgetRow(service: .cursor, title: "Cursor — Max limit (Resets on \(config.cursorBillingResetDay)):", binding: Binding(
                    get: { config.serviceBudgets[AIService.cursor.rawValue] ?? 2000.0 },
                    set: { config.serviceBudgets[AIService.cursor.rawValue] = $0 }
                ))
            }

            if config.isEnterprise(service: .claude) {
                freeBudgetRow(service: .claude, title: "Claude — Max limit (Resets on \(config.claudeBillingResetDay)):", binding: Binding(
                    get: { config.serviceBudgets[AIService.claude.rawValue] ?? 2000.0 },
                    set: { config.serviceBudgets[AIService.claude.rawValue] = $0 }
                ))
            }

            if config.isEnterprise(service: .antigravity) {
                freeBudgetRow(service: .antigravity, title: "Antigravity — Max limit (Resets on \(config.antigravityBillingResetDay)):", binding: Binding(
                    get: { config.serviceBudgets[AIService.antigravity.rawValue] ?? 200.0 },
                    set: { config.serviceBudgets[AIService.antigravity.rawValue] = $0 }
                ))
            }

            let quotaServices = AIService.allCases.filter { !config.isEnterprise(service: $0) }
            if !quotaServices.isEmpty {
                let names = quotaServices.map { $0.displayName }.joined(separator: ", ")
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.purple)
                    Text("\(names) is in Quota Plan mode: remaining % is calculated automatically (no limit or monthly cycle required).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.08)))
            }

            Divider()

            // Notifications
            Text("macOS notification alerts:")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 20) {
                Toggle("At 50% of budget", isOn: Binding(
                    get: { config.alertThresholds.contains(0.50) },
                    set: { on in toggleThreshold(0.50, on: on) }
                ))
                Toggle("At 80% of budget", isOn: Binding(
                    get: { config.alertThresholds.contains(0.80) },
                    set: { on in toggleThreshold(0.80, on: on) }
                ))
                Toggle("At 100% (Exceeded)", isOn: Binding(
                    get: { config.alertThresholds.contains(1.00) },
                    set: { on in toggleThreshold(1.00, on: on) }
                ))
            }
            .font(.caption)
        }
    }

    private func freeBudgetRow(service: AIService, title: String, binding: Binding<Double>) -> some View {
        HStack {
            Image(systemName: service.iconName)
                .foregroundColor(service.brandColor)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
            Spacer()
            TextField("2000", value: binding, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
                .font(.system(.body, design: .monospaced))
            Text(config.currency)
                .font(.caption)
        }
    }

    private func toggleThreshold(_ val: Double, on: Bool) {
        var list = config.alertThresholds
        if on && !list.contains(val) {
            list.append(val)
        } else if !on {
            list.removeAll { $0 == val }
        }
        config.alertThresholds = list.sorted()
    }

    // MARK: - General Tab
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show widget on the right side of the screen on launch", isOn: $config.showSidebarWidgetOnLaunch)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Automatically places the translucent widget on the right side of your screen (notification area).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Text("Automatic refresh interval:")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $config.refreshIntervalMinutes) {
                    Text("Every 5 min").tag(5)
                    Text("Every 15 min").tag(15)
                    Text("Every 30 min").tag(30)
                    Text("Every hour").tag(60)
                }
                .frame(width: 160)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration file:")
                    .font(.subheadline)

                Text(AppConfig.configFileURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(AppConfig.configFileURL.path, inFileViewerRootedAtPath: AppConfig.configDirectoryURL.path)
                }
            }
        }
    }
}
