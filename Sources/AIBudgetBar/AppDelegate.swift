import Cocoa
import SwiftUI
import Combine

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var preferencesWindow: NSWindow?
    private var manager: BudgetManager!
    public var sidebarWidget: SidebarWidgetController!
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        // Create BudgetManager
        manager = BudgetManager()

        // Setup Sidebar Widget Controller
        sidebarWidget = SidebarWidgetController(manager: manager, onOpenPreferences: { [weak self] in
            self?.openPreferences()
        })

        // Setup Menu Bar Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI Budget")
            button.imagePosition = .imageLeading
            button.title = " --"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        // Setup Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 460)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(manager: manager, onOpenPreferences: { [weak self] in
                self?.openPreferences()
            })
        )

        // Observe changes to summary to update Status Bar Item
        manager.$summary
            .receive(on: RunLoop.main)
            .sink { [weak self] summary in
                self?.updateStatusItem(summary: summary)
            }
            .store(in: &cancellables)

        // Initial fetch
        Task {
            await manager.refreshAll()
        }

        // Listen for background refresh & floating window intents from WidgetKit
        setupWidgetIPC()

        // Show sidebar widget if configured
        if manager.config.showSidebarWidgetOnLaunch {
            sidebarWidget.showWidget()
        }
    }

    private var ipcTimer: Timer?

    /// A programmatic AppKit app needs a main menu for standard text shortcuts.
    private func setupMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "AI Budget Tracker")
        appMenu.addItem(withTitle: "Quit AI Budget Tracker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        // Nil targets route each action through the active field's responder chain,
        // including SwiftUI SecureField editors. The default modifier is Command.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func setupWidgetIPC() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(
            self,
            selector: #selector(handleWidgetRefresh(_:)),
            name: NSNotification.Name("com.antigravity.aibudgetbar.refresh"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        dnc.addObserver(
            self,
            selector: #selector(handleWidgetFloating(_:)),
            name: NSNotification.Name("com.antigravity.aibudgetbar.floating"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // Fallback file-based IPC for sandboxed WidgetKit AppIntents
        let refreshTriggerURL = AppConfig.configDirectoryURL.appendingPathComponent("refresh.trigger")
        let floatingTriggerURL = AppConfig.configDirectoryURL.appendingPathComponent("floating.trigger")
        ipcTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            let fm = FileManager.default
            if fm.fileExists(atPath: refreshTriggerURL.path) {
                try? fm.removeItem(at: refreshTriggerURL)
                Task { @MainActor [weak self] in
                    await self?.manager.refreshAll()
                }
            }
            if fm.fileExists(atPath: floatingTriggerURL.path) {
                try? fm.removeItem(at: floatingTriggerURL)
                Task { @MainActor [weak self] in
                    self?.sidebarWidget.showWidget()
                }
            }
        }
    }

    @objc private func handleWidgetRefresh(_ notification: Notification) {
        Task { @MainActor [weak self] in
            await self?.manager.refreshAll()
        }
    }

    @objc private func handleWidgetFloating(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.sidebarWidget.showWidget()
        }
    }

    private func updateStatusItem(summary: BudgetSummary) {
        guard let button = statusItem.button else { return }

        let formattedCost = String(format: "%.2f %@", summary.totalCost, manager.config.currency)
        button.title = " \(formattedCost)"

        let symbolName: String
        if summary.isOverBudget {
            symbolName = "exclamationmark.triangle.fill"
        } else if summary.isWarning {
            symbolName = "chart.line.uptrend.xyaxis"
        } else {
            symbolName = "sparkles"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AI Budget")?.withSymbolConfiguration(config)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    public func openPreferences() {
        popover.performClose(nil)

        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "AI Budget Tracker Preferences"
        window.contentViewController = NSHostingController(rootView: PreferencesView(manager: manager))
        window.isReleasedWhenClosed = false

        self.preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "aibudgetbar" else { continue }
            let host = url.host ?? ""
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            switch host {
            case "preferences", "settings":
                openPreferences()
            case "floating", "window":
                sidebarWidget.showWidget()
            case "refresh":
                Task {
                    await manager.refreshAll()
                }
            case "open":
                if let service = AIService(rawValue: path) {
                    NSWorkspace.shared.open(service.dashboardURL)
                }
            default:
                if let service = AIService(rawValue: host) {
                    NSWorkspace.shared.open(service.dashboardURL)
                }
            }
        }
    }
}
