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
  double amount = fmin(1, fabs(velocity) / 1200.0);
  // Compensate for the engine's gamepad dead zone only while moving.
  return (float)copysign(0.245 + 0.755 * amount, velocity);
}

static inline void pg_swipe_consume(PGSwipeQueue *queue, double seconds, float *x, float *y) {
  *x = pg_swipe_axis(atomic_exchange_explicit(&queue->x, 0, memory_order_relaxed), seconds);
  *y = pg_swipe_axis(atomic_exchange_explicit(&queue->y, 0, memory_order_relaxed), seconds);
}

static inline void pg_swipe_reset(PGSwipeQueue *queue) {
  atomic_store_explicit(&queue->x, 0, memory_order_relaxed);
  atomic_store_explicit(&queue->y, 0, memory_order_relaxed);
}
