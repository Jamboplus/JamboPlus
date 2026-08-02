#!/usr/bin/env bash
# Run everything locally: API + instructions for Flutter apps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "▸ Starting JamboPlus API on http://127.0.0.1:8080"
cd "$ROOT/server"
if [[ ! -d node_modules ]]; then
  npm install
fi

if lsof -i :8080 >/dev/null 2>&1; then
  echo "▸ Port 8080 already in use (API may be running)"
else
  node src/index.js &
  API_PID=$!
  trap 'kill $API_PID 2>/dev/null || true' EXIT
  sleep 1
fi

if curl -sf http://127.0.0.1:8080/health >/dev/null; then
  echo "✓ API healthy: $(curl -sf http://127.0.0.1:8080/health)"
else
  echo "✗ API not responding on :8080"
  exit 1
fi

echo ""
echo "Run in separate terminals:"
echo "  flutter run                          # JamboPlus user app"
echo "  cd adplus && flutter run             # JamboAd admin app"
echo ""
echo "Admin login: admin@jamboad.co.tz / Admin@Jambo2026!"

# Keep API running if we started it
if [[ -n "${API_PID:-}" ]]; then
  wait "$API_PID"
fi
