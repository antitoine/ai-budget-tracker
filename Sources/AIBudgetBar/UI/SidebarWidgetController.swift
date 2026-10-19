import Cocoa
import SwiftUI

@MainActor
public final class SidebarWidgetController: NSObject {
    private var widgetWindow: NSWindow?
    private let manager: BudgetManager
    private var onOpenPreferences: () -> Void

    public init(manager: BudgetManager, onOpenPreferences: @escaping () -> Void) {
        self.manager = manager
        self.onOpenPreferences = onOpenPreferences
        super.init()
    }

    public var isVisible: Bool {
        return widgetWindow?.isVisible ?? false
    }

    public func toggleWidget() {
        if isVisible {
            hideWidget()
        } else {
            showWidget()
        }
    }

    public func showWidget() {
        if let window = widgetWindow {
            window.alphaValue = 1.0
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame

        let width: CGFloat = 355
        let height: CGFloat = 545
        let padding: CGFloat = 20

        // Position on the right side of the screen (Notification Center area)
        let initialX = screenRect.maxX - width - padding
        let initialY = screenRect.maxY - height - padding

        let window = NSWindow(
            contentRect: NSRect(x: initialX, y: initialY, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 1.0

        let rootView = SidebarWidgetView(
            manager: manager,
            onClose: { [weak self] in
                self?.hideWidget()
            },
            onOpenPreferences: { [weak self] in
                self?.onOpenPreferences()
            }
        )

        window.contentViewController = NSHostingController(rootView: rootView)
        self.widgetWindow = window

        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hideWidget() {
        guard let window = widgetWindow else { return }
        window.orderOut(nil)
    }
}
