#!/usr/bin/env bash
# ====================================================================
# Run Hirall POS Cloud Admin Web Portal (Port 3000)
# ====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$SCRIPT_DIR/web-admin"
PORT="${1:-3000}"

cd "$WEB_DIR"

echo "=========================================================="
echo "🌐 Starting Hirall POS Admin Web Portal..."
echo "📍 URL: http://localhost:$PORT"
echo "=========================================================="

python3 -m http.server "$PORT"
