#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include <stdatomic.h>

// Pinned ioMouse fields. Called after the engine polls its mouse and before
// mapping controls, on the input thread. No pointer position or stick is used.
static inline bool pg_touch_mouse_apply(uint8_t *memory, uint64_t size, float x, float y) {
  if (!memory || size < 12839216 || !isfinite(x) || !isfinite(y) || (x == 0 && y == 0)) return false;
  const float pixelsPerPoint = 4;
  _Atomic float *mouseX = (_Atomic float *)(void *)(memory + 12839208);
  _Atomic float *mouseY = (_Atomic float *)(void *)(memory + 12839212);
  atomic_store(mouseX, atomic_load(mouseX) + x * pixelsPerPoint);
  atomic_store(mouseY, atomic_load(mouseY) - y * pixelsPerPoint);
  atomic_fetch_or((_Atomic uint8_t *)(memory + 12839105), 1);
  return true;
}
