#include "NativeSwipeLook.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

// Query bodies are extracted from the real pinned engine during preparation.
// Only the memory transport is substituted. The controller clamps, dead zones
// and our hook execute exactly as compiled into the application.
typedef uint32_t u32;
typedef uint64_t u64;
typedef float f32;
typedef int32_t s32;
typedef struct { uint8_t bytes[256]; } ProbeMemory;
typedef struct { ProbeMemory *w2c_env_memory; } w2c_game;
#define FUNC_PROLOGUE
#define FUNC_EPILOGUE
#define wasm_fabsf fabsf
static uint64_t checked_add_u64(uint64_t a, uint64_t b) { return a + b; }
static uint32_t i32_load_shared(const uint8_t *unused, uint64_t size, ProbeMemory *memory, uint64_t at) {
  uint32_t value;
  assert(at <= sizeof memory->bytes - sizeof value);
  memcpy(&value, memory->bytes + at, sizeof value);
  return value;
}
static uint32_t i32_load8_u_shared(const uint8_t *unused, uint64_t size, ProbeMemory *memory, uint64_t at) {
  assert(at < sizeof memory->bytes);
  return memory->bytes[at];
}
static float f32_load_shared(const uint8_t *unused, uint64_t size, ProbeMemory *memory, uint64_t at) {
  float value;
  assert(at <= sizeof memory->bytes - sizeof value);
  memcpy(&value, memory->bytes + at, sizeof value);
  return value;
}
static ProbeMemory memory;
static float swipeX, swipeY;
static float pg_swipe_control_value(uint64_t binding, float value) {
  return pg_swipe_boost_value(swipeX, swipeY,
    i32_load_shared(NULL, 0, &memory, binding + 16),
    i32_load_shared(NULL, 0, &memory, binding + 20),
    i32_load_shared(NULL, 0, &memory, binding + 24), value);
}
#include "swipe-camera-queries.inc"
static void word(uint64_t at, uint32_t value) { memcpy(memory.bytes + at, &value, sizeof value); }
static void number(uint64_t at, float value) { memcpy(memory.bytes + at, &value, sizeof value); }
int main(void) {
  const uint64_t binding = 16, configuration = 128;
  w2c_game game = {&memory};
  number(binding, 1); number(binding + 4, 1);
  word(binding + 16, 12); word(binding + 20, 4125);
  memory.bytes[binding + 58] = 1;
  number(configuration, .1f);
  assert(w2c_game_f10518(&game, binding, configuration) == 1);
  assert(w2c_game_f10519(&game, binding, configuration) == 1);
  assert(w2c_game_f10521(&game, binding, configuration) == 1);
  swipeX = 4;
  assert(w2c_game_f10518(&game, binding, configuration) == 4);
  assert(w2c_game_f10519(&game, binding, configuration) == 4);
  assert(w2c_game_f10521(&game, binding, configuration) == 4);
  word(binding + 24, 1);
  assert(w2c_game_f10518(&game, binding, configuration) == 1);
  word(binding + 24, 0); word(binding + 20, 4096);
  assert(w2c_game_f10518(&game, binding, configuration) == 1);
  word(binding + 20, 4125); number(binding + 4, 0);
  assert(w2c_game_f10518(&game, binding, configuration) == 0);
  number(binding + 4, 1); swipeX = 0;
  assert(w2c_game_f10518(&game, binding, configuration) == 1);
  puts("Actual engine queries: swipe exceeds controller cap; other pads, movement, zero input and swipe release unchanged.");
}
