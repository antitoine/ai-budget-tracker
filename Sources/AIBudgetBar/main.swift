import Cocoa
import Foundation

let args = CommandLine.arguments

if args.contains("--help") || args.contains("-h") {
    print("""
    AI Budget Bar - Cursor, Antigravity, Claude, and Codex budget tracking on macOS

    Usage:
      AIBudgetBar             Launch the application and display the widget
      AIBudgetBar --widget    Display the floating widget on the right side of the screen
      AIBudgetBar --status    Display the budget summary in the terminal
      AIBudgetBar --json      Export the current summary in JSON format
      AIBudgetBar --config    Display configuration file path
      AIBudgetBar --help      Show this help
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
            print("Month: \(sum.monthName)")
            print(String(format: "Total consumed: %.2f %@ / %.2f %@ (%.1f%%)", sum.totalCost, cfg.currency, sum.totalBudget, cfg.currency, sum.percentUsed))
            print("-----------------------------------------------")
            for s in sum.services {
                if s.isQuotaMode {
                    let qStr = s.quotaPrimaryText ?? "Quotas"
                    let qLim = s.quotaSecondaryText ?? "Personal Plan"
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
