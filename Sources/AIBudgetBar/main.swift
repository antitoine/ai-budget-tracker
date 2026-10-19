import Cocoa
import Foundation

let args = CommandLine.arguments

if args.contains("--help") || args.contains("-h") {
    print("""
    AI Budget Bar - Suivi de budget Cursor, Antigravity et Claude sur macOS

    Usage:
      AIBudgetBar             Lance l'application et affiche le widget
      AIBudgetBar --widget    Affiche le widget flottant à droite de l'écran
      AIBudgetBar --status    Affiche le récapitulatif des budgets dans le terminal
      AIBudgetBar --json      Exporte le récapitulatif actuel au format JSON
      AIBudgetBar --config    Affiche le chemin du fichier de configuration
      AIBudgetBar --help      Affiche cette aide
    """)
    exit(0)
}

if args.contains("--config") {
    print(AppConfig.configFileURL.path)
    exit(0)
}

if args.contains("--status") {
_ = MainActor.assumeIsolated {
        Task {
            let manager = BudgetManager()
            await manager.refreshAll()
            let sum = manager.summary
            let cfg = manager.config

            print("\n================ AI BUDGET BAR ================")
            print("Mois : \(sum.monthName)")
            print(String(format: "Total consommé : %.2f %@ / %.2f %@ (%.1f%%)", sum.totalCost, cfg.currency, sum.totalBudget, cfg.currency, sum.percentUsed))
            print("-----------------------------------------------")
            for s in sum.services {
                if s.isQuotaMode {
                    let qStr = s.quotaPrimaryText ?? "Quotas"
                    let qLim = s.quotaSecondaryText ?? "Forfait Perso"
                    print("• \(s.service.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)) : \(qStr.padding(toLength: 10, withPad: " ", startingAt: 0)) (\(qLim)) - \(s.statusText)")
                } else {
                    let limitStr = String(format: "%.2f %@", s.budgetLimit, cfg.currency)
                    let costStr = String(format: "%.2f %@", s.cost, cfg.currency)
                    print("• \(s.service.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)) : \(costStr.padding(toLength: 10, withPad: " ", startingAt: 0)) (Max: \(limitStr)) - \(s.statusText)")
                }
            }
            print("===============================================\n")
            exit(0)
        }
    }
    dispatchMain()
}

if args.contains("--json") {
_ = MainActor.assumeIsolated {
        Task {
            let manager = BudgetManager()
            await manager.refreshAll()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(manager.summary),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
            exit(0)
        }
    }
    dispatchMain()
}

// GUI Mode (Menu Bar Accessory App)
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
