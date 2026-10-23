#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import subprocess
sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
files=[str(p) for p in Path('App').rglob('*.swift')]
subprocess.run(['xcrun','swiftc','-typecheck','-parse-as-library','-sdk',sdk,
    '-target','arm64-apple-ios16.0','-I','Source','-I','App/GameInstaller',
    '-import-objc-header','Source/Native-Bridging-Header.h',*files],check=True)
print('SWIFT APP TYPECHECK PASSED')
PY
