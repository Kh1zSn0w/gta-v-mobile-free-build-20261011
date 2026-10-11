"""Compile the actual patched engine queries against a small test memory."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
functions = []
for index in [10518, 10519, 10521]:
    signature = f'f32 w2c_game_f{index}(w2c_game* instance, u64 var_p0, u64 var_p1) {{'
    matches = [p for p in (root / 'Generated').glob('game_*.c') if signature in p.read_text()]
    if len(matches) != 1: raise RuntimeError('Missing patched query ' + str(index))
    text = matches[0].read_text()
    start = text.index(signature)
    end = text.index('\n}', start) + 2
    function = text[start:end]
    assert function.count('pg_swipe_control_value(var_p0, var_f0)') == 1
    functions.append(function)
probe = root / 'Build/Probe'
probe.mkdir(parents=True, exist_ok=True)
(probe / 'swipe-camera-queries.inc').write_text('\n'.join(functions))
subprocess.run(['xcrun', 'clang', '-std=c11', '-O2', '-I', str(root / 'Source'),
    '-I', str(probe), str(root / 'Tests/swipe_camera_queries.c'), '-o', str(probe / 'swipe-camera-queries')], check=True)
subprocess.run([str(probe / 'swipe-camera-queries')], check=True)
