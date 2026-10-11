#!/usr/bin/env bash
# Structural gates for the iPhone PWA sign-in keyboard path.
# VM flutter tests cannot open an iOS keyboard — these checks lock the
# architecture that replaced Flutter TextField / HtmlElementView.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo ">>> web keyboard policy (source)"

SIGN_IN=lib/features/auth/sign_in_screen.dart
WEB_FIELD=lib/widgets/native_web_text_field_web.dart
BOOT=web/flutter_bootstrap.js
INDEX=web/index.html

rg -q 'NativeWebTextField\(' "$SIGN_IN" \
  || fail "$SIGN_IN must use NativeWebTextField"
# Count email + code constructors.
count="$(rg -c 'NativeWebTextField\(' "$SIGN_IN" || true)"
[[ "${count:-0}" -ge 2 ]] \
  || fail "$SIGN_IN must use NativeWebTextField for email and code (found $count)"

rg -q '\bTextFormField\s*\(' "$SIGN_IN" \
  && fail "$SIGN_IN must not construct TextFormField (iOS PWA keyboard regression)"
rg -q '\bTextField\s*\(' "$SIGN_IN" \
  && fail "$SIGN_IN must not construct TextField (iOS PWA keyboard regression)"

rg -q 'applyScaffoldChrome\(edgeTints: false\)' "$SIGN_IN" \
  || fail "$SIGN_IN must call applyScaffoldChrome(edgeTints: false)"

rg -q 'sankalpa-overlay-input' "$WEB_FIELD" \
  || fail "$WEB_FIELD must create sankalpa-overlay-input"
rg -q 'body\.append' "$WEB_FIELD" \
  || fail "$WEB_FIELD must append the input to document.body"
rg -q 'position:fixed' "$WEB_FIELD" \
  || fail "$WEB_FIELD must position the overlay input fixed"
rg -q 'HtmlElementView\s*\(' "$WEB_FIELD" \
  && fail "$WEB_FIELD must not use HtmlElementView("

rg -q '_flutter\.loader\.load\(\);' "$BOOT" \
  || fail "$BOOT must call _flutter.loader.load();"
# Comments may mention the forbidden API; only fail if load({…}) passes it.
if rg -U '_flutter\.loader\.load\(\s*\{[^}]*serviceWorkerSettings' "$BOOT" >/dev/null; then
  fail "$BOOT must not call load({ serviceWorkerSettings… })"
fi

rg -q "assetGen = '" "$INDEX" \
  || fail "$INDEX must define assetGen for cache bust"
rg -q 'flutter_bootstrap\.js\?v=' "$INDEX" \
  || fail "$INDEX must load flutter_bootstrap.js?v=…"

echo ">>> web keyboard policy OK"
