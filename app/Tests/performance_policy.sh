#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Pass a booted simulator}"
WORK="$ROOT/Build/PerformancePolicy"
APP="$WORK/Policy.app"
mkdir -p "$APP"
xcrun swiftc -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
 -target arm64-apple-ios16.0-simulator "$ROOT/App/GameSettings.swift" \
 "$ROOT/App/GraphicsPreset.swift" "$ROOT/App/GraphicsOptions.swift" "$ROOT/App/WorldDetail.swift" \
 "$ROOT/Tests/performance_policy.swift" -framework UIKit -framework Metal -o "$APP/Policy"
python3 - "$APP/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
    plistlib.dump({'CFBundleIdentifier':'io.github.playgta5ios.performance-policy','CFBundleExecutable':'Policy',
        'CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1',
        'MinimumOSVersion':'16.0','UILaunchScreen':{}},f)
PY
codesign --force --sign - "$APP"
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch --console "$DEVICE" io.github.playgta5ios.performance-policy > "$WORK/results.log" 2>&1
cat "$WORK/results.log"
grep -q 'PERFORMANCE POLICY CHECKS PASSED' "$WORK/results.log"
