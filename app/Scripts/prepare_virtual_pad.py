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
(root/'Generated/game-virtual-pad-impl.h').write_text('#include "game-impl.h"\nextern void pg_virtual_pad_apply(w2c_game *instance, uint64_t pad);\nextern void pg_touch_mouse_finish(void);\nextern void pg_trainer_tick(w2c_game *instance);\n')
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

# Trainer commands run in the engine's own cheat update, never inside input
# polling or UIKit. Fail the build if any pinned native signature changes.
signatures = [f'void w2c_game_f{i}(w2c_game* instance) {{' for i in
              [37634, 37635, 37636, 37638, 37639, 37641, 37644, 37645, 37646, 37650, 37654]]
signatures += ['void w2c_game_f49437(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2) {']
units = {unit: unit.read_text() for unit in (root / 'Generated').glob('game_*.c')}
for signature in signatures:
    if sum(signature in text for text in units.values()) != 1:
        raise RuntimeError('Pinned trainer function changed: ' + signature)
signature = 'void w2c_game_f37654(w2c_game* instance) {'
unit = next(unit for unit, text in units.items() if signature in text)
text = units[unit]
start = text.index(signature)
end = text.index('\n}', start) + 2
function = text[start:end]
for marker in ['20156136ull', '20156137ull', 'w2c_game_f37635(instance);', 'w2c_game_f37634(instance);']:
    if marker not in function: raise RuntimeError('Pinned cheat update body changed: ' + marker)
# This update is registered with the engine scheduler as callback 27406,
# rather than called directly. Check the table entry and real registration.
all_units = [unit.read_text() for unit in (root / 'Generated').glob('game*.c')]
if not any('(wasm_rt_function_ptr_t)wrap_w2c_game_f37654' in body for body in all_units):
    raise RuntimeError('Cheat update callback table entry changed')
registration = ('  var_j0 = 27406ull;\n  var_j1 = var_l4;\n  var_j2 = 512ull;\n'
                '  var_j1 += var_j2;\n  var_i2 = 0u;\n'
                '  w2c_game_f8883(instance, var_j0, var_j1, var_i2);')
if not any(registration in body for body in units.values()):
    raise RuntimeError('Cheat update scheduler registration changed')
old = '  FUNC_EPILOGUE;\n}'
new = '  pg_trainer_tick(instance);\n' + old
if new not in function:
    if function.count(old) != 1: raise RuntimeError('Cheat update has unexpected exits')
    text = text[:start] + function.replace(old, new) + text[end:]
if include not in text: text = text.replace('#include "game-impl.h"', include, 1)
if unit.read_text() != text: unit.write_text(text)
print('TRAINER ENGINE HOOK VERIFIED: native cheat update, 12 pinned functions, invincibility branch.')
