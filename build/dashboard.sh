#!/bin/bash
# Build script: generates artifact version of harness-dashboard (extras/ → /dist/)
# Inline storage.js mocking; ready to paste into Claude artifact.
# Usage: ./build/dashboard.sh
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"

SRC="$REPO/extras/harness-dashboard.jsx"
DIST="$REPO/dist/harness-dashboard-artifact.jsx"

[ -f "$SRC" ] || { echo "ERROR: $SRC not found"; exit 1; }

mkdir -p "$REPO/dist"

# Strip imports (artifact mode has React available globally)
# and inline localStorage stub
cat "$SRC" | \
  sed '/^import.*React/d' | \
  sed '/^import.*useState/d' | \
  cat - > "$DIST.tmp"

# Inline localStorage stub
cat >> "$DIST.tmp" << 'EOF'

// Artifact mode: localStorage available; sync to metrics.md on export
const exportMetricsAsMarkdown = () => {
  const metrics = JSON.parse(localStorage.getItem('harness_metrics') || '[]');
  const md = "# Exported Metrics\n\n" +
    "| Date | Task | Status | Tokens | Cost |\n" +
    "|------|------|--------|--------|------|\n" +
    metrics.map(m => `| ${m.date} | ${m.task} | ${m.status} | ${m.tokens} | $${m.cost} |`).join('\n');
  return md;
};
EOF

mv "$DIST.tmp" "$DIST"
chmod 644 "$DIST"

echo ">> Built: $DIST"
echo "   Paste into Claude artifact; metrics sync via localStorage ↔ your docs/metrics.md"
