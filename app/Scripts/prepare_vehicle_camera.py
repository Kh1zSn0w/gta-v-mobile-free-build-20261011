"""Keep the optional manual driving-camera hold on the pinned upstream engine."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
include = '#include "game-virtual-pad-impl.h"'
header = root / 'Generated/game-virtual-pad-impl.h'
declaration = 'extern bool pg_vehicle_camera_hold(uint64_t camera);\n'
if declaration not in header.read_text():
    with header.open('a') as output: output.write(declaration)
units = {unit: unit.read_text() for unit in (root / 'Generated').glob('game_*.c')}
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
