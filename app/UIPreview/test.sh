#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DEVICE=$(cat preview-device.txt)
xcodebuild -project LauncherPreview.xcodeproj -scheme LauncherPreview -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath Build -parallel-testing-enabled NO -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO test > ui-tests.log 2>&1 || { tail -80 ui-tests.log; exit 1; }
grep -E 'Test Case.*passed|Executed|TEST SUCCEEDED' ui-tests.log
