#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="${REPO_ROOT}/README.md"
REPORT="${REPO_ROOT}/broken-links.md"

if [ ! -f "$README" ]; then
  echo "ERROR: $README not found"
  exit 1
fi

URLS=$(grep -oP '\((https?://[^)]+)\)' "$README" | sed 's/[()]//g' | sort -u)

if [ -z "$URLS" ]; then
  echo "No URLs found in $README"
  exit 0
fi

TOTAL=$(echo "$URLS" | wc -l)
COUNT=0
BROKEN=""

echo "Testing $TOTAL URLs..."

for url in $URLS; do
  COUNT=$((COUNT + 1))
  printf "  [%d/%d] %s ... " "$COUNT" "$TOTAL" "$url"

  RESPONSE=$(curl -sL -o /dev/null -w "%{http_code} %{url_effective}" --max-time 15 "$url" 2>/dev/null || true)
  CODE=$(echo "$RESPONSE" | awk '{print $1}')
  EFFECTIVE=$(echo "$RESPONSE" | awk '{print $2}')

  if [ "$CODE" = "000" ]; then
    echo "FAIL (timeout/DNS)"
    BROKEN="${BROKEN}- [ ] \`$url\` - Timeout or DNS failure (000)
"
  elif [ "$CODE" -ge 400 ] 2>/dev/null; then
    echo "FAIL ($CODE)"
    BROKEN="${BROKEN}- [ ] \`$url\` - HTTP $CODE
"
  else
    echo "OK ($CODE)"
  fi
done

if [ -z "$BROKEN" ]; then
  echo "
All $TOTAL URLs are OK!"
  rm -f "$REPORT"
  exit 0
fi

BROKEN_COUNT=$(echo "$BROKEN" | grep -c '^\-')

cat > "$REPORT" <<HEREDOC
# Broken Links Report

Generated: $(date -u +"%Y-%m-%d %H:%M UTC")

**$BROKEN_COUNT broken link(s) found** out of $TOTAL total URLs in \`README.md\`.

## Broken Links

$BROKEN
## How to Fix

1. Check each URL above manually
2. Search for an updated URL or archived version
3. Update the link in \`README.md\`
4. Re-run this script: \`bash scripts/check-links.sh\`
HEREDOC

echo "
$BROKEN_COUNT broken link(s) found. See $REPORT"
