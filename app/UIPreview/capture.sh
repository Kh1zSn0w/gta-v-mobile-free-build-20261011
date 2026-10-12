#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate
xcodebuild -project LauncherPreview.xcodeproj -scheme LauncherPreview -sdk iphonesimulator -configuration Debug -derivedDataPath Build CODE_SIGNING_ALLOWED=NO build > preview-build.log 2>&1 || { tail -80 preview-build.log; exit 1; }
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for a in d["devices"].values() for x in a if "iPhone" in x["name"] and ("Pro Max" in x["name"])))')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" Build/Build/Products/Debug-iphonesimulator/LauncherPreview.app
mkdir -p Screenshots
for SHOT in home mode-picker landscape loading graphics files trainer-preview trainer-powers-preview trainer-vehicles-preview trainer-world-preview trainer-character-preview; do
  xcrun simctl terminate "$DEVICE" io.github.playgta5ios.launcher-preview || true
  ARG=""
  [ "$SHOT" = home ] || ARG="--$SHOT"
  xcrun simctl launch "$DEVICE" io.github.playgta5ios.launcher-preview $ARG
  sleep 4
  xcrun simctl io "$DEVICE" screenshot "Screenshots/$SHOT.png"
done
echo "$DEVICE" > preview-device.txt
