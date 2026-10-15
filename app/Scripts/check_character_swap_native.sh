#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun clang -std=c11 -O2 -Wall -Wextra -I Source Tests/character_swap_native.c -o Build/Probe/character-swap-native
Build/Probe/character-swap-native
