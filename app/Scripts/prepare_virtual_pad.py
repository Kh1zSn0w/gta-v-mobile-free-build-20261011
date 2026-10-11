"""Feed a host-provided virtual controller into the pinned engine's pad 0.

ioPad::Update (f10454) clears each pad and only fills it from DirectInput
joysticks, which this build never has. The hook runs after that, so the
engine sees an ordinary connected gamepad: controller layouts, assisted aim
and analog driving all use their normal code paths.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'Generated/game_0.c'
s=p.read_text()
start=s.index('void w2c_game_f10454(w2c_game* instance, u64 var_p0) {')
end=s.index('\nvoid w2c_game_f',start+10)
f=s[start:end]
old='  var_j0 = var_p0;\n  w2c_game_f10456(instance, var_j0);\n  FUNC_EPILOGUE;\n}'
new='  pg_virtual_pad_apply(instance, var_p0);\n'+old
previous='  pg_virtual_pad_apply(var_p0);\n'+old
f=f.replace(previous,old)
if new not in f:
    if f.count(old)!=1:raise RuntimeError('Pinned ioPad::Update changed')
    if 'u64 var_j0 = var_p0;' in f or '12839904ull' not in f:raise RuntimeError('Unexpected ioPad::Update body')
    f=f.replace(old,new)
    s=s[:start]+f+s[end:]
include='#include "game-virtual-pad-impl.h"'
if include not in s:
    s=s.replace('#include "game-impl.h"',include,1)
(root/'Generated/game-virtual-pad-impl.h').write_text('#include "game-impl.h"\nextern void pg_virtual_pad_apply(w2c_game *instance, uint64_t pad);\nextern void pg_touch_mouse_finish(void);\n')
if p.read_text()!=s:p.write_text(s)

# The v1.6 query multiplier is deliberately gone: touch now enters the
# mouse mapper before camera queries, preserving the original query bodies.
for unit in (root/'Generated').glob('game_*.c'):
    text = unit.read_text()
    updated = text.replace('  var_f0 = pg_swipe_control_value(var_p0, var_f0);\n', '')
    if text != updated: unit.write_text(updated)

signature = 'void w2c_game_f65444(w2c_game* instance) {'
matches = [unit for unit in (root/'Generated').glob('game_*.c') if signature in unit.read_text()]
if len(matches) != 1: raise RuntimeError('Pinned input frame completion changed')
unit = matches[0]
text = unit.read_text()
start = text.index(signature)
end = text.index('\n}', start) + 2
function = text[start:end]
if '12839208ull' not in function or function.count('w2c_game_f10454(instance, var_j0);') != 4:
    raise RuntimeError('Pinned mouse/pad input frame no longer matches')
old = '  FUNC_EPILOGUE;\n}'
new = '  pg_touch_mouse_finish();\n' + old
if new not in function:
    if function.count(old) != 1: raise RuntimeError('Input frame has unexpected exits')
    text = text[:start] + function.replace(old, new) + text[end:]
if include not in text: text = text.replace('#include "game-impl.h"', include, 1)
if unit.read_text() != text: unit.write_text(text)
print('Direct touch mouse input and input-frame completion prepared.')
