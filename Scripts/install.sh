#!/usr/bin/env bash
# Installs ServicesPanel.app to /Applications and optionally adds a LaunchAgent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$PROJECT_ROOT/build/ServicesPanel.app"
DEST="/Applications/ServicesPanel.app"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS/com.ricardobarria.services-panel.plist"

if [[ ! -d "$APP" ]]; then
    echo "App not built yet. Run ./Scripts/bundle.sh first."
    exit 1
fi

echo "▸ Installing to /Applications …"
rm -rf "$DEST"
cp -r "$APP" "$DEST"

read -r -p "Launch automatically at login? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    mkdir -p "$LAUNCH_AGENTS"
    cat > "$PLIST_PATH" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ricardobarria.services-panel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ServicesPanel.app/Contents/MacOS/ServicesPanel</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLIST_EOF
    launchctl load "$PLIST_PATH" 2>/dev/null || true
    echo "✓ LaunchAgent installed at $PLIST_PATH"
fi

echo ""
echo "✓ Installed at $DEST"
echo "  Opening…"
open "$DEST"
