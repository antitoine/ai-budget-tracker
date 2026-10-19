#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Compilation (si non déjà compilé)
if [ ! -d "$PROJECT_ROOT/build/AIBudgetBar.app" ]; then
    "$SCRIPT_DIR/build.sh"
fi

# Prioritize /Applications so macOS WidgetKit / chronod can discover the widget
if [ -w "/Applications" ]; then
    DEST_DIR="/Applications"
else
    DEST_DIR="$HOME/Applications"
fi
mkdir -p "$DEST_DIR"

APP_SOURCE="$PROJECT_ROOT/build/AIBudgetBar.app"
APP_DEST="$DEST_DIR/AIBudgetBar.app"

echo "==> Fermeture des instances existantes..."
pkill -9 -x AIBudgetBar 2>/dev/null || true
sleep 0.5

# Remove duplicate in ~/Applications so LaunchServices / pluginkit doesn't conflict
if [ "$DEST_DIR" = "/Applications" ] && [ -d "$HOME/Applications/AIBudgetBar.app" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$HOME/Applications/AIBudgetBar.app" 2>/dev/null || true
    rm -rf "$HOME/Applications/AIBudgetBar.app"
fi

echo "==> Installation dans $APP_DEST..."
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"

# Re-verify signature & entitlements in /Applications
WIDGET_ENTITLEMENTS="$PROJECT_ROOT/build/widget.entitlements"
codesign -s - --force --entitlements "$WIDGET_ENTITLEMENTS" "$APP_DEST/Contents/PlugIns/AIBudgetWidget.appex"
codesign -s - --force "$APP_DEST"

# Ensure ~/.config/ai-budget-bar is readable by WidgetKit extension
chmod 755 "$HOME/.config" 2>/dev/null || true
chmod 755 "$HOME/.config/ai-budget-bar" 2>/dev/null || true

# 2. Enregistrement de l'extension de Widget macOS
echo "==> Enregistrement du widget dans LaunchServices & WidgetKit..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$APP_DEST" 2>/dev/null || true
pluginkit -a "$APP_DEST/Contents/PlugIns/AIBudgetWidget.appex" 2>/dev/null || true
pluginkit -e use -i com.antigravity.aibudgetbar.widget 2>/dev/null || true

# Recharger chronod et NotificationCenter pour actualiser la galerie de widgets
echo "==> Rechargement de chronod et NotificationCenter..."
killall -9 chronod NotificationCenter 2>/dev/null || true

# Create CLI symlink in ~/.local/bin or /usr/local/bin
if [ -d "$HOME/.local/bin" ]; then
    ln -sf "$APP_DEST/Contents/MacOS/AIBudgetBar" "$HOME/.local/bin/aibudget"
fi

echo "==> Synchronisation initiale des dépenses (Cursor CSV + Antigravity + Claude)..."
"$APP_DEST/Contents/MacOS/AIBudgetBar" --status || true

echo "==> Lancement du widget sur votre écran..."
open "$APP_DEST"

echo "==> Vérification PlugInKit :"
pluginkit -m -v -i com.antigravity.aibudgetbar.widget || true

