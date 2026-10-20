"""Preserve the custom trainer and manual driving camera on upstream builds."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
include = '#include "game-virtual-pad-impl.h"'
header = root / 'Generated/game-virtual-pad-impl.h'
with header.open('a') as output:
    output.write('extern void pg_trainer_tick(w2c_game *instance);\nextern bool pg_vehicle_camera_hold(uint64_t camera);\n')
# Trainer commands run in the engine's own cheat update, never inside input
# polling or UIKit. Fail the build if any pinned native signature changes.
signatures = [f'void w2c_game_f{i}(w2c_game* instance) {{' for i in
              [37634, 37635, 37636, 37638, 37639, 37641, 37644, 37645, 37646, 37650, 37654]]
signatures += ['void w2c_game_f49437(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2) {']
signatures += ['void w2c_game_f37642(w2c_game* instance, u64 var_p0, u32 var_p1) {', 'void w2c_game_f52794(w2c_game* instance, u64 var_p0) {', 'void w2c_game_f52797(w2c_game* instance) {', 'void w2c_game_f52798(w2c_game* instance) {', 'u32 w2c_game_f37934(w2c_game* instance, u64 var_p0) {', 'void w2c_game_f53007(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f53008(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f53009(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f53010(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f58714(w2c_game* instance) {', 'u32 w2c_game_f58715(w2c_game* instance) {', 'void w2c_game_f58753(w2c_game* instance, u32 var_p0, f32 var_p1) {', 'void w2c_game_f58754(w2c_game* instance, u32 var_p0, f32 var_p1) {', 'void w2c_game_f58646(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f58699(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f58779(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2) {', 'u32 w2c_game_f57184(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f61578(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f50154(w2c_game* instance, u32 var_p0, u64 var_p1) {', 'void w2c_game_f50156(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'f32 w2c_game_f50032(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f52941(w2c_game* instance, u32 var_p0) {']
signatures += ['void w2c_game_f58625(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f60322(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f60324(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f60327(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f60347(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f60348(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f50040(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f57381(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'u32 w2c_game_f57382(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'u32 w2c_game_f57383(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'u32 w2c_game_f57384(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'u32 w2c_game_f57385(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2) {', 'u32 w2c_game_f57386(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2) {', 'u32 w2c_game_f57391(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3) {', 'void w2c_game_f57392(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3, u32 var_p4) {', 'void w2c_game_f57393(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f57394(w2c_game* instance, u32 var_p0) {', 'void w2c_game_f57395(w2c_game* instance, u32 var_p0) {', 'u32 w2c_game_f57435(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f57436(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3, u32 var_p4) {', 'u32 w2c_game_f57438(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f57439(w2c_game* instance, u32 var_p0, u32 var_p1) {', 'void w2c_game_f57440(w2c_game* instance, u32 var_p0) {']
units = {unit: unit.read_text() for unit in (root / 'Generated').glob('game_*.c')}
for signature in signatures:
    if sum(signature in text for text in units.values()) != 1:
        raise RuntimeError('Pinned trainer function changed: ' + signature)
# Fail before compilation if the per-frame flag writer or argument layout differs.
checks = {53010: ['16384u', '4328u'], 53009: ['8192u', '4328u'],
          53007: ['2048u', '4328u'], 53008: ['4096u', '4328u'],
          37642: ['w2c_game_f680(', 'w2c_game_f4633(', '65535u'],
          50154: ['8u', '16u', 'w2c_game_f8693('],
          58754: ['1.5f', '1.0f', '3872u'], 58753: ['1.5f', '736u']}
for index, markers in checks.items():
    pattern = r'\n(?:void|u32|u64|f32) w2c_game_f' + str(index) + r'\([^\n]+\) \{'
    body = next(body for body in units.values() if re.search(pattern, body))
    match = re.search(pattern, body)
    function = body[match.start():body.index('\n}', match.end()) + 2]
    for marker in markers:
        if marker not in function: raise RuntimeError('Pinned power body changed: ' + str(index) + ' ' + marker)
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
print('TRAINER ENGINE HOOK VERIFIED: native cheat update, 57 pinned functions, invincibility branch.')

# Preserve manual vehicle look by skipping only its automatic pull-around method.
camera_signature = 'void w2c_game_f27019(w2c_game* instance, u64 var_p0, u64 var_p1, u64 var_p2) {'
camera_unit = next(unit for unit, body in units.items() if camera_signature in body)
camera_text = camera_unit.read_text()
start = camera_text.index(camera_signature)
end = camera_text.index('\n}', start) + 2
function = camera_text[start:end]
for marker in ['w2c_game_f26967(instance, var_j0, var_j1, var_j2);', '1360u', '1364u', '544u']:
    if marker not in function: raise RuntimeError('Vehicle pull-around body changed: ' + marker)
old = '  FUNC_PROLOGUE;'
new = '  if (pg_vehicle_camera_hold(var_p0)) return;\n' + old
if new not in function:
    if function.count(old)!=1: raise RuntimeError('Unexpected vehicle camera prologue')
    camera_text = camera_text[:start] + function.replace(old,new,1) + camera_text[end:]
if include not in camera_text: camera_text = camera_text.replace('#include "game-impl.h"',include,1)
camera_unit.write_text(camera_text)
print('VEHICLE CAMERA HOLD VERIFIED: manual look bypasses automatic pull-around; input and collision paths unchanged.')
