#include "NativeTouchMouse.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef uint32_t u32;
typedef uint64_t u64;
typedef float f32;
typedef int32_t s32;
typedef int64_t s64;
typedef struct { _Alignas(8) uint8_t bytes[32000000]; } ProbeMemory;
typedef struct { ProbeMemory *w2c_env_memory; } w2c_game;
#define FUNC_PROLOGUE
#define FUNC_EPILOGUE
#define wasm_fabsf fabsf
static uint64_t checked_add_u64(uint64_t a, uint64_t b) { return a + b; }
#define LOAD(name, result, storage) \
static result name(const uint8_t *unused, uint64_t size, ProbeMemory *memory, uint64_t at) { \
  storage value; assert(at <= sizeof memory->bytes - sizeof value); \
  memcpy(&value, memory->bytes + at, sizeof value); return (result)value; }
#define STORE(name, storage) \
static void name(const uint8_t *unused, uint64_t size, ProbeMemory *memory, uint64_t at, storage value) { \
  assert(at <= sizeof memory->bytes - sizeof value); memcpy(memory->bytes + at, &value, sizeof value); }
LOAD(i32_load_shared, u32, uint32_t)
LOAD(i32_load8_u_shared, u32, uint8_t)
LOAD(i32_load8_s_shared, u32, int8_t)
LOAD(i32_load16_s_shared, u32, int16_t)
LOAD(i64_load_shared, u64, uint64_t)
LOAD(i64_load8_u_shared, u64, uint8_t)
LOAD(i64_load32_s_shared, u64, int32_t)
LOAD(f32_load_shared, float, float)
STORE(i32_store_shared, uint32_t)
STORE(i32_store8_shared, uint8_t)
STORE(i64_store_shared, uint64_t)
STORE(f32_store_shared, float)
static ProbeMemory memory;
#include "swipe-camera-queries.inc"
static void word(uint64_t at, uint32_t value) { memcpy(memory.bytes + at, &value, sizeof value); }
static void wide(uint64_t at, uint64_t value) { memcpy(memory.bytes + at, &value, sizeof value); }
static void number(uint64_t at, float value) { memcpy(memory.bytes + at, &value, sizeof value); }
static const uint64_t mapping = 1024, binding = 8192, configuration = 16384;
static void setup(uint32_t source, uint32_t axis) {
  memset(&memory, 0, sizeof memory);
  word(mapping, 1); word(mapping + 36, source); word(mapping + 2796, 0xfc000000u | axis);
  wide(mapping + 5560, binding); number(binding, 1); word(binding + 52, UINT32_MAX);
  memory.bytes[binding + 58] = 1;
  number(configuration, .25f);
  number(4339280, 1); number(4339280 + 6 * 4, 1);
  number(4339308, 1); number(4339308 + 6 * 4, 1);
}
static float camera(w2c_game *game) {
  w2c_game_f10490(game, mapping, 16, 1);
  return w2c_game_f10519(game, binding, configuration);
}
int main(void) {
  w2c_game game = {&memory};
  setup(3, 512);
  assert(pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, .125f, 0));
  float tiny = camera(&game);
  assert(fabsf(tiny - .5f / 127) < .000001f);
  assert(i32_load_shared(NULL, 0, &memory, binding + 16) == 3);
  assert((int32_t)i32_load_shared(NULL, 0, &memory, binding + 24) == -4);
  setup(3, 512); pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, .25f, 0);
  assert(fabsf(camera(&game) - tiny * 2) < .000001f);
  setup(3, 512); pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, -.125f, 0);
  assert(fabsf(camera(&game) + tiny) < .000001f);
  setup(3, 513); pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, 0, .125f);
  assert(fabsf(camera(&game) + tiny) < .000001f);
  setup(3, 518); pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, .125f, 0);
  assert(fabsf(camera(&game) - tiny) < .000001f);
  number(12839208, 0); number(12839212, 0);
  assert(camera(&game) == 0);
  setup(12, 4096); word(mapping + 2796, 4096);
  memory.bytes[12840656 + 20] = 255;
  assert(fabsf(camera(&game) - 1) < .000001f);
  setup(3, 512); memory.bytes[12840656 + 20] = 255;
  pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, .125f, 0);
  assert(fabsf(camera(&game) - tiny) < .000001f);
  assert(memory.bytes[12840656 + 20] == 255);
  assert(!pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, 0, 0));
  assert(!pg_touch_mouse_apply(memory.bytes, sizeof memory.bytes, NAN, 0));
  puts("Actual engine mouse mapper: subpixel gestures are linear, reverse correctly, stop without drift and preserve pad movement. Original camera queries have no controller swipe multiplier.");
}
