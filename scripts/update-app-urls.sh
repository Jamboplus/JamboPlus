#!/usr/bin/env bash
# Sync production API URL into JamboPlus + JamboAd Flutter configs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="${1:-}"

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <https://your-api.up.railway.app>"
  exit 1
fi

# Normalize: ensure https, no trailing slash
URL="${URL%/}"
if [[ "$URL" != http* ]]; then
  URL="https://$URL"
fi

USER_API="$ROOT/lib/core/constants/api_config.dart"
ADMIN_API="$ROOT/adplus/lib/core/config/admin_api_config.dart"

for file in "$USER_API" "$ADMIN_API"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing: $file"
    exit 1
  fi
  sed -i "s|static const _productionUrl = '[^']*';|static const _productionUrl = '$URL';|" "$file"
done

echo "$URL" > "$ROOT/scripts/.railway-url"
echo "Updated Flutter production URL → $URL"
echo "  - lib/core/constants/api_config.dart"
echo "  - adplus/lib/core/config/admin_api_config.dart"
