#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${1:?Pass a booted simulator}"
WORK="$ROOT/Build/NightPreview"
APP="$WORK/NightPreview.app"
mkdir -p "$APP" "$ROOT/Build/Screenshots"
xcrun swiftc -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios16.0-simulator \
  "$ROOT/App/HomeView.swift" "$ROOT/App/Theme.swift" \
  "$ROOT/App/SettingsHomeViewController.swift" "$ROOT/App/TrainerHomeViewController.swift" \
  "$ROOT/Tests/NightPreview.swift" -framework UIKit -o "$APP/NightPreview"
cp "$ROOT/Resources/NightCity.png" "$ROOT/Resources/NightSettings.png" "$APP/"
cp "$ROOT/App/Assets.xcassets/HomeIcon.imageset/HomeIcon@2x.png" "$APP/HomeIcon@2x.png"
python3 - "$APP/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
    plistlib.dump({'CFBundleIdentifier':'io.github.playgta5ios.night-preview','CFBundleExecutable':'NightPreview',
        'CFBundleName':'GTA V MOBILE','CFBundleVersion':'16','CFBundleShortVersionString':'2.4',
        'CFBundlePackageType':'APPL','MinimumOSVersion':'16.0','UILaunchScreen':{},
        'UISupportedInterfaceOrientations':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']},f)
PY
codesign --force --sign - "$APP"
xcrun simctl install "$DEVICE" "$APP"
for SHOT in home settings trainer; do
  xcrun simctl terminate "$DEVICE" io.github.playgta5ios.night-preview || true
  xcrun simctl launch "$DEVICE" io.github.playgta5ios.night-preview "--$SHOT"
  sleep 3
  xcrun simctl io "$DEVICE" screenshot "$ROOT/Build/Screenshots/$SHOT.png"
done
echo 'NIGHT UI PREVIEW CAPTURED'
