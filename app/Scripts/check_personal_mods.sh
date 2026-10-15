#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Build/Probe
for test in trainer_queue vehicle_camera memory_budget; do
  xcrun clang -std=c11 -O2 -Wall -Wextra -I Source "Tests/$test.c" -lm -o "Build/Probe/$test"
  "Build/Probe/$test"
done
for test in trainer_engine sandbox_store; do
  xcrun clang -std=c11 -O2 -Wall -Wextra -I Source "Tests/$test.c" Source/NativeSandboxStore.c -lm -lpthread -o "Build/Probe/$test"
  "Build/Probe/$test"
done
swiftc App/PersonalSettingsMigration.swift Tests/settings_migration.swift -o Build/Probe/settings-migration
Build/Probe/settings-migration
