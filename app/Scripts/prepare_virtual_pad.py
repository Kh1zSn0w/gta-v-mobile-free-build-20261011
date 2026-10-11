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
(root/'Generated/game-virtual-pad-impl.h').write_text('#include "game-impl.h"\nextern void pg_virtual_pad_apply(w2c_game *instance, uint64_t pad);\nextern float pg_swipe_control_value(uint64_t binding, float value);\n')
if p.read_text()!=s:p.write_text(s)

# Current-value queries: bounded signed, unbounded signed, and bounded
# positive. Historical queries remain untouched, so button transitions and
# menu navigation keep their original timing. Guard every pinned function.
for index in [10518, 10519, 10521]:
    signature = f'f32 w2c_game_f{index}(w2c_game* instance, u64 var_p0, u64 var_p1) {{'
    matches = [unit for unit in (root/'Generated').glob('game_*.c') if signature in unit.read_text()]
    if len(matches) != 1: raise RuntimeError(f'Pinned camera query f{index} changed')
    unit = matches[0]
    text = unit.read_text()
    start = text.index(signature)
    end = text.index('\n}', start) + 2
    function = text[start:end]
    old = '  FUNC_EPILOGUE;\n  return var_f0;'
    new = '  var_f0 = pg_swipe_control_value(var_p0, var_f0);\n' + old
    if new not in function:
        if function.count(old) != 1 or ', 4u)' not in function or 'f32_load_shared' not in function:
            raise RuntimeError(f'Pinned camera query f{index} no longer matches')
        text = text[:start] + function.replace(old, new) + text[end:]
    if include not in text: text = text.replace('#include "game-impl.h"', include, 1)
    if unit.read_text() != text: unit.write_text(text)
print('Swipe camera queries patched after controller normalization.')
