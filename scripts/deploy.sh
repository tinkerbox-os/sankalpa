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

# Portable regex helpers (perl ships with macOS; ripgrep may not be installed).
# Whole-file matching, so patterns can span lines.
match() { PAT="$1" perl -0777 -ne 'exit(/$ENV{PAT}/ ? 0 : 1)' "$2"; }
count_matches() { PAT="$1" perl -0777 -ne 'my $c = () = /$ENV{PAT}/g; print $c' "$2"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MSG="${1:-Deploy: $(date +%Y-%m-%d) update}"

if [ ! -f supabase.env.json ]; then
  echo "ERROR: supabase.env.json missing. Create it from supabase.env.example.json first."
  exit 1
fi

echo ">>> Smoke checks (analyze + test)"
"$REPO_ROOT/scripts/smoke_check.sh"

echo ">>> Building Flutter web with --base-href=/sankalpa/"
touch web/.nojekyll
BUILD_STAMP="$(date -u +%Y%m%d-%H%M)"
echo "    BUILD_STAMP=$BUILD_STAMP"
# pwa-strategy=none + custom web/flutter_bootstrap.js (no serviceWorkerSettings).
# Flutter's default bootstrap still registered flutter_service_worker.js and
# pinned stale shells on iOS home-screen installs.
flutter build web \
  --base-href=/sankalpa/ \
  --pwa-strategy=none \
  --release \
  --dart-define-from-file=supabase.env.json \
  --dart-define=BUILD_STAMP="$BUILD_STAMP"

# Stamp HTML meta so clients can detect a new deploy and wipe Cache Storage.
if [ -f build/web/index.html ]; then
  sed -i.bak \
    "s/name=\"sankalpa-build\" content=\"[^\"]*\"/name=\"sankalpa-build\" content=\"${BUILD_STAMP}\"/" \
    build/web/index.html
  rm -f build/web/index.html.bak
  grep -q "name=\"sankalpa-build\" content=\"${BUILD_STAMP}\"" build/web/index.html \
    || { echo "ERROR: failed to stamp sankalpa-build meta"; exit 1; }
  echo "    index.html sankalpa-build=$BUILD_STAMP"
fi

# The FlutterLoader source mentions serviceWorkerSettings as a parameter name;
# only fail if our load() *call* passes it.
if match '_flutter\.loader\.load\(\s*\{[^}]*serviceWorkerSettings' \
    build/web/flutter_bootstrap.js >/dev/null; then
  echo "ERROR: flutter_bootstrap.js still registers a service worker."
  echo "       Ensure web/flutter_bootstrap.js calls _flutter.loader.load() with no SW settings."
  exit 1
fi
if ! match '_flutter\.loader\.load\(\);' build/web/flutter_bootstrap.js; then
  echo "ERROR: expected _flutter.loader.load(); in flutter_bootstrap.js"
  exit 1
fi
echo "    flutter_bootstrap.js: load() without service worker ✓"

# Query-bust main.dart.js inside the embedded buildConfig. Safari HTTP-caches
# bare main.dart.js even after Cache Storage is wiped; index.html already
# loads flutter_bootstrap.js?v=… — this makes the entrypoint match.
if [ -f build/web/flutter_bootstrap.js ]; then
  sed -i.bak \
    "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=${BUILD_STAMP}\"/" \
    build/web/flutter_bootstrap.js
  rm -f build/web/flutter_bootstrap.js.bak
  grep -q "main.dart.js?v=${BUILD_STAMP}" build/web/flutter_bootstrap.js \
    || { echo "ERROR: failed to stamp mainJsPath cache bust"; exit 1; }
  echo "    mainJsPath=main.dart.js?v=${BUILD_STAMP}"
fi

# Prove the iPhone PWA keyboard path survived dart2js (tree-shaking / a
# mistaken TextField revert would drop this marker).
if [ -f build/web/main.dart.js ]; then
  match 'sankalpa-overlay-input' build/web/main.dart.js \
    || {
      echo "ERROR: built main.dart.js is missing sankalpa-overlay-input"
      echo "       Sign-in must ship the body-level DOM overlay field."
      exit 1
    }
  echo "    main.dart.js contains sankalpa-overlay-input ✓"
fi

# Never publish Flutter's SW artifact — an old registration can update() onto
# this file and re-pin a stale shell even with --pwa-strategy=none.
rm -f build/web/flutter_service_worker.js
echo "    removed flutter_service_worker.js from publish set"

# Point the installable start URL at this deploy's bust token so home-screen
# launches do not reuse a cache-key that omits ?_b=.
if [ -f build/web/manifest.json ]; then
  sed -i.bak \
    "s|\"start_url\": *\"[^\"]*\"|\"start_url\": \"./?_b=${BUILD_STAMP}.c5\"|" \
    build/web/manifest.json
  rm -f build/web/manifest.json.bak
  grep -q "\"start_url\": \"./?_b=${BUILD_STAMP}.c5\"" build/web/manifest.json \
    || { echo "ERROR: failed to stamp manifest start_url"; exit 1; }
  echo "    manifest start_url=./?_b=${BUILD_STAMP}.c5"
fi

# Optional custom SW (audio). Stamp bust token if present — not registered
# while PWA is paused, but keep file coherent for a future re-enable.
if [ -f build/web/sw.js ]; then
  sed -i.bak "s/const APP_CACHE_BUST = 'dev';/const APP_CACHE_BUST = '${BUILD_STAMP}';/" build/web/sw.js
  rm -f build/web/sw.js.bak
  echo "    APP_CACHE_BUST=$BUILD_STAMP"
fi

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
