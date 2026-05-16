#!/usr/bin/env bash
# Run this after every codeplain re-render from the project root:
#   bash scripts/post-render-patch.sh
set -e

DIST="$(cd "$(dirname "$0")/.." && pwd)/dist"

echo "==> Post-render patch: $DIST"

# ── 1. src/lib/utils.ts (required by every shadcn/ui component) ──────────────
UTILS="$DIST/src/lib/utils.ts"
if [ ! -f "$UTILS" ] || ! grep -q "twMerge" "$UTILS"; then
  echo "  [patch] writing src/lib/utils.ts"
  mkdir -p "$(dirname "$UTILS")"
  cat > "$UTILS" <<'EOF'
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF
fi

# ── 2. package.json fixes ─────────────────────────────────────────────────────
PKG="$DIST/package.json"

# 2a. dev script: prisma migrate deploy → prisma db push
if grep -q "prisma migrate deploy" "$PKG"; then
  echo "  [patch] fixing dev script (prisma migrate deploy → prisma db push)"
  sed -i '' 's/prisma migrate deploy/prisma db push/g' "$PKG"
fi

# 2b. missing runtime deps: clsx, tailwind-merge, tailwindcss-animate
node -e "
const fs = require('fs');
const pkgPath = '$PKG';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const required = { 'clsx': '^2.1.1', 'tailwind-merge': '^3.6.0', 'tailwindcss-animate': '^1.0.7' };
let changed = false;
for (const [name, version] of Object.entries(required)) {
  if (!pkg.dependencies[name]) {
    console.log('  [patch] adding missing dep: ' + name);
    pkg.dependencies[name] = version;
    changed = true;
  }
}
if (changed) fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
"

# ── 3. npm install to pick up any newly added deps ───────────────────────────
echo "  [patch] running npm install in dist/"
(cd "$DIST" && npm install --legacy-peer-deps --silent)

echo "==> Patch complete. Run: cd dist && npm run dev"
