#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixtureRoot=$(mktemp -d "${TMPDIR:-/tmp}/pg-asset-ci.XXXXXX")
mkdir "$fixtureRoot/data"
python3 Scripts/asset_test_server.py "$fixtureRoot" > "$fixtureRoot/port" &
serverPID=$!
trap 'kill "$serverPID" 2>/dev/null || true; rm -rf "$fixtureRoot"' EXIT
for attempt in {1..100}; do [ -s "$fixtureRoot/port" ] && break; sleep 0.1; done
port=$(head -n 1 "$fixtureRoot/port")
[[ "$port" =~ ^[0-9]+$ ]] || { echo "Invalid test server port"; exit 1; }
printf "health" > "$fixtureRoot/data/health"
curl --fail --silent --show-error --noproxy '*' --retry 3 -H "Range: bytes=0-5" "http://127.0.0.1:$port/data/health"
echo " Local streaming test server ready on port $port"
export PG_LOCAL_MIRROR="$fixtureRoot"
export PG_ASSET_TEST_SERVER="http://127.0.0.1:$port"
bash Scripts/check_asset_pipeline.sh
