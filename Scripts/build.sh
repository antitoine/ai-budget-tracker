#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> 1. Compilation de AIBudgetBar (Application principale & Widget latéral)..."

BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/AIBudgetBar.app"
CACHE_DIR="$BUILD_DIR/cache"
PLUGINS_DIR="$APP_BUNDLE/Contents/PlugIns"
WIDGET_APPEX="$PLUGINS_DIR/AIBudgetWidget.appex"

mkdir -p "$CACHE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$WIDGET_APPEX/Contents/MacOS"
mkdir -p "$WIDGET_APPEX/Contents/Resources"

MAIN_SOURCES=(
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/AIService.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/AppConfig.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/ServiceUsage.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Services/AntigravityTracker.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Services/CursorTracker.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Services/ClaudeTracker.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Services/BudgetManager.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/HistoryChartView.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/ServiceRowView.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/PreferencesView.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/PopoverView.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/SidebarWidgetView.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/UI/SidebarWidgetController.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/AppDelegate.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/main.swift"
)

swiftc \
  -module-cache-path "$CACHE_DIR" \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Combine \
  -framework WidgetKit \
  -O \
  "${MAIN_SOURCES[@]}" \
  -o "$APP_BUNDLE/Contents/MacOS/AIBudgetBar"

cp "$APP_BUNDLE/Contents/MacOS/AIBudgetBar" "$BUILD_DIR/AIBudgetBar"
chmod +x "$APP_BUNDLE/Contents/MacOS/AIBudgetBar" "$BUILD_DIR/AIBudgetBar"

# Write Info.plist for main app
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr_FR</string>
    <key>CFBundleExecutable</key>
    <string>AIBudgetBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.aibudgetbar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIBudgetBar</string>
    <key>CFBundleDisplayName</key>
    <string>AI Budget Tracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.antigravity.aibudgetbar</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>aibudgetbar</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "==> 2. Compilation de l'extension WidgetKit macOS (Centre de notifications)..."

WIDGET_SOURCES=(
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/AIService.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/AppConfig.swift"
  "$PROJECT_ROOT/Sources/AIBudgetBar/Models/ServiceUsage.swift"
  "$PROJECT_ROOT/Sources/AIBudgetWidget/AIBudgetWidget.swift"
)

swiftc \
  -module-cache-path "$CACHE_DIR" \
  -parse-as-library \
  -application-extension \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -module-name AIBudgetWidget \
  -framework WidgetKit \
  -framework AppIntents \
  -framework SwiftUI \
  -framework Foundation \
  -O \
  "${WIDGET_SOURCES[@]}" \
  -o "$WIDGET_APPEX/Contents/MacOS/AIBudgetWidget"

chmod +x "$WIDGET_APPEX/Contents/MacOS/AIBudgetWidget"

# Write Info.plist for Widget Extension
cat << 'EOF' > "$WIDGET_APPEX/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>fr_FR</string>
    <key>CFBundleExecutable</key>
    <string>AIBudgetWidget</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.aibudgetbar.widget</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIBudgetWidget</string>
    <key>CFBundleDisplayName</key>
    <string>AI Budget Tracker</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
EOF

# Write Entitlements for WidgetKit Extension (required by macOS Notification Center / chronod)
WIDGET_ENTITLEMENTS="$BUILD_DIR/widget.entitlements"
cat << 'EOF' > "$WIDGET_ENTITLEMENTS"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
    <array>
        <string>/.config/ai-budget-bar/</string>
    </array>
</dict>
</plist>
EOF

# Sign bundles ad-hoc for macOS security (sign appex with entitlements first, then outer app without --deep overwriting appex)
echo "==> 3. Signature des composants macOS (ad-hoc avec entitlements WidgetKit)..."
codesign -s - --force --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET_APPEX"
codesign -s - --force "$APP_BUNDLE"

echo "==> Bundle complet généré avec succès dans $APP_BUNDLE"
