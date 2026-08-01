#!/usr/bin/env bash
# Fast gate before deploy: static analysis + widget/unit tests for critical
# workflows (auth, ritual theme lock, browser chrome tints, sign-out).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo ">>> flutter analyze"
flutter analyze

echo ">>> flutter test"
flutter test
