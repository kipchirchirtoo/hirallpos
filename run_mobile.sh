#!/usr/bin/env bash
# ====================================================================
# Run Hirall POS Mobile Companion App (Android / Web / Linux)
# ====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$SCRIPT_DIR/mobile-app"
PORT="${1:-3001}"

cd "$MOBILE_DIR"

echo "=========================================================="
echo "📱 Starting Hirall POS Mobile Companion App..."
echo "📍 Mobile Web URL: http://localhost:$PORT"
echo "📍 LAN Access:     Open on your Android phone browser!"
echo "=========================================================="

flutter pub get

# If an Android device/emulator is connected, you can run on it directly:
# flutter run -d android
# Otherwise runs as mobile web PWA on port 3001:
flutter run -d web-server --web-port "$PORT" --web-hostname 0.0.0.0
