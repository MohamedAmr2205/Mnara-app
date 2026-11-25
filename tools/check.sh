#!/usr/bin/env bash
# Local quality gate (macOS/Linux/Git Bash): pub get, format, analyze, test.
set -euo pipefail

echo '==> flutter pub get'
flutter pub get
echo '==> dart format'
dart format .
echo '==> flutter analyze'
flutter analyze
echo '==> flutter test'
flutter test
echo 'All checks passed.'
