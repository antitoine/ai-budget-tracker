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
                Text("Plafonds Budgétaires").tag(1)
                Text("Général").tag(2)
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

                Button("Fermer") {
                    NSApplication.shared.keyWindow?.close()
                }

                Button("Enregistrer et actualiser") {
                    manager.updateConfig(config)
                    saveStatusMessage = "Configuration enregistrée !"
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
                        Text("🏢 Entreprise").tag(true)
                        Text("👤 Forfait (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .cursor) {
                    HStack {
                        Text("Jour de réinitialisation du cycle mensuel :")
                            .font(.subheadline)
                        Spacer()
                        TextField("16", value: $config.cursorBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("du mois")
                            .font(.caption)
                    }
                }

                Text("Cookie de session (WorkosCursorSessionToken) :")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("Collez votre WorkosCursorSessionToken", text: $config.cursorSessionToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("✓ Synchronisation automatique via l'export CSV Cursor (Team #\(config.cursorTeamId)).")
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
                        Text("🏢 Entreprise").tag(true)
                        Text("👤 Forfait (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .claude) {
                    HStack {
                        Text("Jour de réinitialisation du cycle mensuel :")
                            .font(.subheadline)
                        Spacer()
                        TextField("1", value: $config.claudeBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("du mois")
                            .font(.caption)
                    }
                }

                Text("Cookie sessionKey claude.ai (synchronisation 100% automatique) :")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("sk-ant-sid02-...", text: $config.claudeSessionCookie)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !config.claudeSessionCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("✓ Synchronisation automatique active avec claude.ai/settings/usage.")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    HStack {
                        Text("Ou montant manuel de secours :")
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
                        Text("🏢 Entreprise").tag(true)
                        Text("👤 Forfait (Quotas)").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 210)
                }

                if config.isEnterprise(service: .antigravity) {
                    HStack {
                        Text("Jour de réinitialisation du cycle mensuel :")
                            .font(.subheadline)
                        Spacer()
                        TextField("18", value: $config.antigravityBillingResetDay, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                        Text("du mois")
                            .font(.caption)
                    }
                }

                Toggle("Scanner automatiquement l'activité locale (~/.gemini/antigravity/brain)", isOn: $config.antigravityScanBrainDir)
                    .font(.caption)

                Text(config.isEnterprise(service: .antigravity)
                     ? "✓ Mode Entreprise : coût estimé inclus dans le budget global."
                     : "✓ Mode Forfait Personnel : affiche uniquement le % de quota restant sur fenêtre glissante (sans cycle mensuel ni montant $).")
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
                Text("Devise d'affichage :")
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
                    Text("Budget Global Mensuel Entreprise (champ libre) :")
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
                Text("Enveloppe globale allouée par votre entreprise (en plus des plafonds max de chaque outil). Seuls les outils marqués « 🏢 Entreprise » sont comptabilisés dans ce total.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Per-Service Maximum Limits (only for Enterprise services)
            Text("Limites maximum par outil (🏢 Entreprise — champs libres) :")
                .font(.subheadline)
                .fontWeight(.bold)

            if config.isEnterprise(service: .cursor) {
                freeBudgetRow(service: .cursor, title: "Cursor — Plafond max (Réinit. le \(config.cursorBillingResetDay)) :", binding: Binding(
                    get: { config.serviceBudgets[AIService.cursor.rawValue] ?? 2000.0 },
                    set: { config.serviceBudgets[AIService.cursor.rawValue] = $0 }
                ))
            }

            if config.isEnterprise(service: .claude) {
                freeBudgetRow(service: .claude, title: "Claude — Plafond max (Réinit. le \(config.claudeBillingResetDay)er) :", binding: Binding(
                    get: { config.serviceBudgets[AIService.claude.rawValue] ?? 2000.0 },
                    set: { config.serviceBudgets[AIService.claude.rawValue] = $0 }
                ))
            }

            if config.isEnterprise(service: .antigravity) {
                freeBudgetRow(service: .antigravity, title: "Antigravity — Plafond max (Réinit. le \(config.antigravityBillingResetDay)) :", binding: Binding(
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
                    Text("\(names) est en mode Forfait à quotas : le % restant est calculé automatiquement (aucun plafond ni cycle mensuel à saisir).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.08)))
            }

            Divider()

            // Notifications
            Text("Alertes de notifications macOS :")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 20) {
                Toggle("À 50% du budget", isOn: Binding(
                    get: { config.alertThresholds.contains(0.50) },
                    set: { on in toggleThreshold(0.50, on: on) }
                ))
                Toggle("À 80% du budget", isOn: Binding(
                    get: { config.alertThresholds.contains(0.80) },
                    set: { on in toggleThreshold(0.80, on: on) }
                ))
                Toggle("À 100% (Dépassé)", isOn: Binding(
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
                Toggle("Afficher le widget à droite de l'écran au démarrage", isOn: $config.showSidebarWidgetOnLaunch)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Place automatiquement le widget translucide à droite de votre écran (zone des notifications).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Text("Intervalle d'actualisation automatique :")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $config.refreshIntervalMinutes) {
                    Text("Toutes les 5 min").tag(5)
                    Text("Toutes les 15 min").tag(15)
                    Text("Toutes les 30 min").tag(30)
                    Text("Toutes les heures").tag(60)
                }
                .frame(width: 160)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Fichier de configuration :")
                    .font(.subheadline)

                Text(AppConfig.configFileURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Button("Révéler dans le Finder") {
                    NSWorkspace.shared.selectFile(AppConfig.configFileURL.path, inFileViewerRootedAtPath: AppConfig.configDirectoryURL.path)
                }
            }
        }
    }
}
