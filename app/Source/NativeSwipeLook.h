#pragma once
#include <math.h>
#include <stdint.h>
#include <stdatomic.h>

typedef struct { _Atomic int32_t x, y; } PGSwipeQueue;

static inline void pg_swipe_add_axis(_Atomic int32_t *axis, float delta) {
  if (!isfinite(delta) || delta == 0) return;
  int32_t add = (int32_t)lroundf(fmaxf(-4096, fminf(4096, delta)) * 256);
  int32_t old = atomic_load_explicit(axis, memory_order_relaxed);
  int32_t next;
  do {
    int64_t total = (int64_t)old + add;
    next = (int32_t)(total < -2097152 ? -2097152 : total > 2097152 ? 2097152 : total);
  } while (!atomic_compare_exchange_weak_explicit(axis, &old, next,
             memory_order_relaxed, memory_order_relaxed));
}

static inline float pg_swipe_axis(int32_t travel, double seconds) {
  if (!travel) return 0;
  if (!isfinite(seconds) || seconds <= 0) seconds = 1.0 / 60;
  seconds = fmax(1.0 / 240, fmin(seconds, 0.1));
  double velocity = travel / (256.0 * seconds);
  // Keep swipe speed independently of the pad's byte range. The camera
  // query applies speeds above one after the engine's controller clamp.
  return (float)fmax(-8, fmin(8, velocity / 240.0));
}

static inline float pg_swipe_pad_axis(float speed) {
  if (!isfinite(speed) || speed == 0) return 0;
  // The pinned mapper detects axes beyond 0.25. Tiny drags must count too.
  return copysignf(0.26f + 0.74f * fminf(1, fabsf(speed)), speed);
}

static inline float pg_swipe_boost_value(float x, float y, uint32_t source,
    uint32_t axis, uint32_t pad, float value) {
  if (source != 12 || pad != 0 || value == 0 || !isfinite(value)) return value;
  float speed;
  switch (axis) {
    case 4098: speed = x; break;             // full right X
    case 4099: speed = -y; break;            // full right Y (down positive)
    case 4122: speed = fmaxf(0, y); break;   // look up
    case 4123: speed = fmaxf(0, -y); break;  // look down
    case 4124: speed = fmaxf(0, -x); break;  // look left
    case 4125: speed = fmaxf(0, x); break;   // look right
    default: return value;
  }
  if (!isfinite(speed) || fabsf(speed) <= 1 || signbit(speed) != signbit(value)) return value;
  return value * fminf(8, fabsf(speed));
}

static inline void pg_swipe_consume(PGSwipeQueue *queue, double seconds, float *x, float *y) {
  *x = pg_swipe_axis(atomic_exchange_explicit(&queue->x, 0, memory_order_relaxed), seconds);
  *y = pg_swipe_axis(atomic_exchange_explicit(&queue->y, 0, memory_order_relaxed), seconds);
}

static inline void pg_swipe_reset(PGSwipeQueue *queue) {
  atomic_store_explicit(&queue->x, 0, memory_order_relaxed);
  atomic_store_explicit(&queue->y, 0, memory_order_relaxed);
}
