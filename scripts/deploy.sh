#!/usr/bin/env bash
# Deploy Sankalpa Flutter web build to GitHub Pages.
#
# Mirrors the Prayers app pattern:
#   - main branch  = source code only
#   - gh-pages branch = compiled web build at root
#   - GitHub Pages serves from gh-pages /
#
# Usage:
#   ./scripts/deploy.sh "Optional commit message"
#
# Requires:
#   - flutter on PATH (fvm-managed is fine)
#   - supabase.env.json present at repo root (gitignored)
#   - git remote 'origin' pointing to github.com/tinkerbox-os/sankalpa.git

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MSG="${1:-Deploy: $(date +%Y-%m-%d) update}"

if [ ! -f supabase.env.json ]; then
  echo "ERROR: supabase.env.json missing. Create it from supabase.env.example.json first."
  exit 1
fi

echo ">>> Building Flutter web with --base-href=/sankalpa/"
touch web/.nojekyll
flutter build web \
  --base-href=/sankalpa/ \
  --release \
  --dart-define-from-file=supabase.env.json

echo ">>> Publishing to gh-pages branch"
cd build/web
rm -rf .git
git init -q -b gh-pages
git config user.name "gautam-os"
git config user.email "gautam-os@users.noreply.github.com"
git add -A
git commit -q -m "$MSG"
git push -f https://github.com/tinkerbox-os/sankalpa.git gh-pages:gh-pages

echo ">>> Done. Live in ~1 minute at:"
echo "    https://tinkerbox-os.github.io/sankalpa/"
