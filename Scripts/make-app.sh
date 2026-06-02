#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="burnrate.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/burnrate "$APP/Contents/MacOS/burnrate"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so Keychain + notifications behave.
codesign --force --deep --sign - "$APP"
echo "Built $APP"
echo "Run with: open $APP   (or: ./$APP/Contents/MacOS/burnrate for console logs)"
