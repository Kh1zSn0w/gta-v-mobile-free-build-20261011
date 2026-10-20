#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p Build/Probe
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/swipe_queue.c -o Build/Probe/swipe-queue
Build/Probe/swipe-queue
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/audio_ring.c -o Build/Probe/audio-ring
Build/Probe/audio-ring
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/memory_budget.c -o Build/Probe/memory-budget
Build/Probe/memory-budget

xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/vehicle_camera.c -o Build/Probe/vehicle-camera
Build/Probe/vehicle-camera

xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/asset_read_cache.c -o Build/Probe/asset-read-cache
Build/Probe/asset-read-cache
