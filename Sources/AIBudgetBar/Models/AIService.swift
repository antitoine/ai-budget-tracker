import Foundation
import SwiftUI

public enum AIService: String, CaseIterable, Identifiable, Codable {
    case cursor = "cursor"
    case antigravity = "antigravity"
    case claude = "claude"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        case .claude: return "Claude"
        }
    }

    public var subtitle: String {
        switch self {
        case .cursor: return "Cursor IDE & Agent"
        case .antigravity: return "Google Antigravity"
        case .claude: return "Anthropic API & Claude"
        }
    }

    public var iconName: String {
        switch self {
        case .cursor: return "chevron.left.forwardslash.chevron.right"
        case .antigravity: return "sparkles"
        case .claude: return "bubble.left.and.text.bubble.right.fill"
        }
    }

    public var brandColor: Color {
        switch self {
        case .cursor: return Color(red: 0.18, green: 0.53, blue: 1.0)       // Cursor Blue
        case .antigravity: return Color(red: 0.40, green: 0.72, blue: 0.38)  // Mint / Sage
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)       // Anthropic Coral
        }
    }

    public var dashboardURL: URL {
        switch self {
        case .cursor:
            return URL(string: "https://cursor.com/dashboard/usage")!
        case .antigravity:
            return URL(string: "https://antigravity.google/")!
        case .claude:
            return URL(string: "https://claude.ai/new#settings/usage")!
        }
    }

    public var widgetDeepLinkURL: URL {
        return URL(string: "aibudgetbar://open/\(rawValue)")!
    }
}
