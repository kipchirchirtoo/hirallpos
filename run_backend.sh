#!/usr/bin/env bash
# ====================================================================
# Run Hirall POS FastAPI Backend (Linux Dev)
# ====================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"

cd "$BACKEND_DIR"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "[Hirall POS] Creating Python virtual environment..."
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r requirements.txt
fi

echo "=========================================================="
echo "🚀 Starting Hirall POS FastAPI Backend on Linux..."
echo "📍 Base API URL:   http://192.168.100.30:8000/api/v1"
echo "📖 Swagger Docs:   http://192.168.100.30:8000/docs"
echo "🩺 Health Check:   http://192.168.100.30:8000/health"
echo "=========================================================="

./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
