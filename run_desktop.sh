#!/usr/bin/env bash
# ====================================================================
# Run Hirall POS Flutter Desktop Client (Linux Dev)
# ====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$SCRIPT_DIR/desktop-app"
API_URL="${1:-http://192.168.100.30:8000/api/v1}"

cd "$DESKTOP_DIR"

echo "=========================================================="
echo "🖥️  Starting Hirall POS Flutter Desktop on Linux..."
echo "🔗 Connected API URL: $API_URL"
echo "=========================================================="

flutter pub get

flutter run -d linux --dart-define=API_URL="$API_URL"
