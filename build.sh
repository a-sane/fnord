#!/bin/bash
# Builds build/Fnord.app. Signs with your Apple Development cert if present so
# macOS permissions (Accessibility, Mic, Screen Recording) survive rebuilds.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Fnord.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Fnord "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

IDENTITY=$(security find-identity -p codesigning -v | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed: ${IDENTITY:-ad-hoc})"
