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
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/trainer_queue.c -o Build/Probe/trainer-queue
Build/Probe/trainer-queue
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/trainer_engine.c Source/NativeSandboxStore.c -o Build/Probe/trainer-engine
Build/Probe/trainer-engine

xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/vehicle_camera.c -o Build/Probe/vehicle-camera
Build/Probe/vehicle-camera

xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/asset_read_cache.c -o Build/Probe/asset-read-cache
Build/Probe/asset-read-cache

xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/sandbox_store.c Source/NativeSandboxStore.c -o Build/Probe/sandbox-store
Build/Probe/sandbox-store

xcrun clang++ -std=c++17 -O2 -Wall -Wextra -I Source Tests/frame_rate.cpp -o Build/Probe/frame-rate
Build/Probe/frame-rate
xcrun clang++ -std=c++17 -O2 -Wall -Wextra -I Source Tests/frame_metrics.cpp -o Build/Probe/frame-metrics
Build/Probe/frame-metrics
