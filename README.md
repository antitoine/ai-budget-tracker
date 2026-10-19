# ✦ AI Budget Tracker & Widgets for macOS

**AI Budget Tracker** allows you to **track your AI spending and usage** across **Cursor**, **Antigravity**, **Claude**, and **Codex**, with **two widget formats dedicated to the right side of your screen (Notifications & Desktop)**:

1. 📱 **Official Apple Widget (WidgetKit)**: directly integrated into the **macOS Notification Center** (right sidebar) and placeable on your desktop.
2. 🪟 **Floating Sidebar Widget**: an ultra-sleek frosted glass card that automatically docks to the right edge of your screen, perfect if your menu bar is crowded!

![AI Budget Bar macOS](https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![Design](https://img.shields.io/badge/UI-SwiftUI%20%26%20WidgetKit-purple)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📸 Sidebar Widget Preview (Right Notification Area)

```text
                                        ┌───────────────────────────────┐
                                        │ ✨ AI Budget Widget      ⚙️ ⨉ │
                                        ├───────────────────────────────┤
                                        │ $42.80        October 2026    │
                                        │ of $100       Left: $57.20    │
                                        │ [██████████░░░░░░] 42.8%      │
                                        ├───────────────────────────────┤
                                        │ [</>] Cursor        $21.60 ↗  │
                                        │       265 / 500 requests      │
                                        │ [✨]  Antigravity   $11.45 ↗  │
                                        │       14 sessions (172k tok)  │
                                        │ [💬]  Claude        $14.80 ↗  │
                                        │       Sonnet 3.5 & 3.7        │
                                        ├───────────────────────────────┤
                                        │ 📊 7-Day Trend                │
                                        │     █    █         █          │
                                        │   █ █  █ █   █   █ █          │
                                        │  Mon Tue Wed Thu Fri Sat Sun  │
                                        ├───────────────────────────────┤
                                        │ 🔄 Refresh  (Right Edge)      │
                                        └───────────────────────────────┘
```

---

## ✨ Key Features

1. **Native Dock-less macOS Integration (`LSUIElement`)**:
   - Sits discreetly in the menu bar at the top of the screen.
   - Displays monthly total in real time (`✨ $42.80`).
   - The icon automatically adapts (green/neutral below budget, orange approaching threshold, red if exceeded).

2. **Choose Which Services to Track**:
   - Enable or disable each AI in **Preferences → Services & Cycles**, then click **Save and Refresh**.
   - Disabled services keep their settings, stop making requests and scanning local activity, and are excluded from service lists, totals, charts, alerts, and widgets.
   - **Cursor**:
     - Supports the `WorkosCursorSessionToken` session cookie (retrieves exact fast request counts and monthly cost).
     - Also supports Team Admin API keys (`api.cursor.com`).
     - Accounts for fixed Pro plan ($20/month) + usage-based overages.
   - **Antigravity**:
     - **Real-time local scanner**: directly parses local session logs and transcripts (`~/.gemini/antigravity/brain/*/transcript.jsonl`).
     - Accurately tracks input, output, and cached tokens (Gemini 2.5/3.8 Flash & Pro) and calculates real cost.
   - **Claude (Anthropic)**:
     - Connects to Anthropic billing Admin API (`/v1/organizations/cost_report` and `usage_report/messages`).
     - Supports monthly Claude Pro fixed plan if desired.
   - **Codex (OpenAI)**:
     - Displays recent 5-hour and weekly quota snapshots recorded by local Codex sessions, without an API key.
     - Shows unavailable when no supported, unexpired snapshot exists. Run Codex locally to record an update.
     - Enterprise mode supports a manually entered billing-cycle spend; local quota snapshots do not provide billed amounts.

3. **7-Day Trend Chart**:
   - Mini stacked bar chart showing day-by-day budget expenditure for each tool.

4. **Smart Threshold Alerts**:
   - Automatic macOS system notifications when crossing 50%, 80%, or 100% of your budget limit.

5. **Dual Mode: Menu Bar App & CLI Tool**:
   - Queryable directly from the terminal (`AIBudgetBar --status` or `AIBudgetBar --json`).

---

## 🚀 Installation & Launch

### Quick method (1 command):
From the project folder, simply run:

```bash
make install
```

This command compiles the application, installs it into `~/Applications/AIBudgetBar.app`, and launches it immediately! The icon appears instantly in your menu bar.

### Other useful commands:
```bash
make build    # Compiles the application into ./build/AIBudgetBar.app
make status   # Displays the budget summary directly in the terminal
make json     # Exports the summary in JSON format
make clean    # Removes compilation artifacts
```

---

## ⚙️ Configuring Keys & Services

To configure your credentials, click the menu bar icon and select **⚙️ Preferences** (or directly edit `~/.config/ai-budget-bar/config.json`):

All four services are enabled by default, including when opening an older configuration. Use the service switches to hide any you do not use. Switches persist in the `enabledServices` dictionary, for example `"enabledServices": {"cursor": false, "codex": true}`. Standard macOS editing shortcuts, including **⌘V** to paste into cookie and key fields, work in Preferences.

### 1. Cursor
- Go to [cursor.com/dashboard](https://www.cursor.com/dashboard)
- Open browser Developer Tools (`F12` or `Inspect`) > **Application** / **Storage** tab > **Cookies** > `https://www.cursor.com`
- Copy the `WorkosCursorSessionToken` cookie value and paste it into Preferences.

### 2. Antigravity
- Enabled by default! The local tracker automatically scans your active sessions in `~/.gemini/antigravity/brain`. No API key required.

### 3. Claude (Anthropic)
- Go to [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
- Create or copy an Admin key starting with `sk-ant-admin...` (required to access organization cost reports).

### 4. Codex (OpenAI)
- Select **Plan (Quotas)** for local quota tracking. The tracker reads `sessions` and `archived_sessions` under `~/.codex`, or under `CODEX_HOME` when set. You can also enter a Codex home directory in Preferences (takes priority over the environment variable).
- These [local session locations](https://learn.chatgpt.com/docs/reference/troubleshooting#feedback-and-logs) contain the quota snapshots recorded by Codex. Only quota metadata is used; no credentials or transcript contents are sent to an API.
- Scanning is bounded to the last 512 KiB of the 64 most recently modified session files from the last seven days. Values describe the most recent recorded snapshot, not a live account query, and expired windows are shown as unavailable.
- Select **Enterprise** to enter the current cycle's spend and reset day manually. Update the amount each cycle. Manual totals contribute to the budget and alerts but are excluded from the daily chart because there is no daily billing breakdown.

## Validation

On macOS, run `swift test` and `make build`. The build also compiles and packages the WidgetKit extension. GitHub Actions runs both checks on macOS.

---

## 📁 Project Structure

```text
.
├── Makefile                     # Make targets: build, install, status, clean
├── Package.swift                # Swift Package manifest
├── README.md                    # Complete documentation
├── Scripts/
│   ├── build.sh                 # Build and .app packaging script
│   └── install.sh               # Install into ~/Applications & launch
└── Sources/
    ├── AIBudgetBar/
    │   ├── AppDelegate.swift    # NSStatusItem, NSPopover and window management
    │   ├── main.swift           # CLI and GUI entry point
    │   ├── Models/
    │   │   ├── AIService.swift    # Service definitions, colors, icons
    │   │   ├── AppConfig.swift    # Persistence (~/.config/ai-budget-bar/config.json)
    │   │   └── ServiceUsage.swift # Consumption models and history
    │   ├── Services/
    │   │   ├── AntigravityTracker.swift # Local ~/.gemini transcript scanner
    │   │   ├── BudgetManager.swift      # Coordination, notifications, and cache
    │   │   ├── ClaudeTracker.swift      # Anthropic Admin Cost Report API client
    │   │   ├── CodexTracker.swift       # Local Codex quota snapshots / manual spend
    │   │   └── CursorTracker.swift      # Cursor API client and session cookies
    │   └── UI/
    │       ├── HistoryChartView.swift   # 7-day stacked bar chart
    │       ├── PopoverView.swift        # Main macOS popover view
    │       ├── PreferencesView.swift    # Settings window
    │       ├── ServiceRowView.swift     # Detailed card for each service
    │       ├── SidebarWidgetController.swift # Floating sidebar window controller
    │       └── SidebarWidgetView.swift  # Floating sidebar widget view
    └── AIBudgetWidget/
        └── AIBudgetWidget.swift         # macOS Notification Center WidgetKit extension
```
