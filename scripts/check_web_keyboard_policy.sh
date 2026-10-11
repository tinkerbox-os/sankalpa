#!/usr/bin/env bash
# Structural gates for the iPhone PWA sign-in keyboard path.
# VM flutter tests cannot open an iOS keyboard — these checks lock the
# architecture that replaced Flutter TextField / HtmlElementView.
set -euo pipefail

# Portable regex helpers (perl ships with macOS; ripgrep may not be installed).
# Whole-file matching, so patterns can span lines.
match() { PAT="$1" perl -0777 -ne 'exit(/$ENV{PAT}/ ? 0 : 1)' "$2"; }
count_matches() { PAT="$1" perl -0777 -ne 'my $c = () = /$ENV{PAT}/g; print $c' "$2"; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo ">>> web keyboard policy (source)"

SIGN_IN=lib/features/auth/sign_in_screen.dart
WEB_FIELD=lib/widgets/native_web_text_field_web.dart
BOOT=web/flutter_bootstrap.js
INDEX=web/index.html

match 'NativeWebTextField\(' "$SIGN_IN" \
  || fail "$SIGN_IN must use NativeWebTextField"
# Count email + code constructors.
count="$(count_matches 'NativeWebTextField\(' "$SIGN_IN" || true)"
[[ "${count:-0}" -ge 2 ]] \
  || fail "$SIGN_IN must use NativeWebTextField for email and code (found $count)"

match '\bTextFormField\s*\(' "$SIGN_IN" \
  && fail "$SIGN_IN must not construct TextFormField (iOS PWA keyboard regression)"
match '\bTextField\s*\(' "$SIGN_IN" \
  && fail "$SIGN_IN must not construct TextField (iOS PWA keyboard regression)"

match 'applyScaffoldChrome\(edgeTints: false\)' "$SIGN_IN" \
  || fail "$SIGN_IN must call applyScaffoldChrome(edgeTints: false)"

match 'sankalpa-overlay-input' "$WEB_FIELD" \
  || fail "$WEB_FIELD must create sankalpa-overlay-input"
match 'body\.append' "$WEB_FIELD" \
  || fail "$WEB_FIELD must append the input to document.body"
match 'position:fixed' "$WEB_FIELD" \
  || fail "$WEB_FIELD must position the overlay input fixed"
match 'HtmlElementView\s*\(' "$WEB_FIELD" \
  && fail "$WEB_FIELD must not use HtmlElementView("

match '_flutter\.loader\.load\(\);' "$BOOT" \
  || fail "$BOOT must call _flutter.loader.load();"
# Comments may mention the forbidden API; only fail if load({…}) passes it.
if match '_flutter\.loader\.load\(\s*\{[^}]*serviceWorkerSettings' "$BOOT" >/dev/null; then
  fail "$BOOT must not call load({ serviceWorkerSettings… })"
fi

match "assetGen = '" "$INDEX" \
  || fail "$INDEX must define assetGen for cache bust"
match 'flutter_bootstrap\.js\?v=' "$INDEX" \
  || fail "$INDEX must load flutter_bootstrap.js?v=…"

echo ">>> web keyboard policy OK"
