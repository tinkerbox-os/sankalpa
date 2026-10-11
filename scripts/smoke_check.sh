#!/usr/bin/env bash
# Fast gate before deploy: static analysis + widget/unit tests for critical
# workflows (auth, ritual theme lock, browser chrome tints, CTA contrast,
# sign-in email colours, sign-out) + structural web-keyboard policy.
# See docs/REGRESSION.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ">>> flutter analyze"
flutter analyze

echo ">>> flutter test"
flutter test

# VM tests cannot open an iOS soft keyboard. This locks the architecture that
# replaced Flutter TextField / HtmlElementView on sign-in.
"$REPO_ROOT/scripts/check_web_keyboard_policy.sh"

echo ">>> smoke_check OK (see docs/REGRESSION.md — iPhone PWA keyboard still needs a device pass)"
