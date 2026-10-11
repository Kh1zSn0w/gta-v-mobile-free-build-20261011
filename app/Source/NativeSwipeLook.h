#pragma once
#include <math.h>
#include <stdint.h>
#include <stdatomic.h>

typedef struct { _Atomic int32_t x, y; } PGSwipeQueue;

static inline void pg_swipe_add_axis(_Atomic int32_t *axis, float delta) {
  if (!isfinite(delta) || delta == 0) return;
  int32_t add = (int32_t)lroundf(fmaxf(-4096, fminf(4096, delta)) * 65536);
  int32_t old = atomic_load_explicit(axis, memory_order_relaxed);
  int32_t next;
  do {
    int64_t total = (int64_t)old + add;
    next = (int32_t)(total < -536870912 ? -536870912 : total > 536870912 ? 536870912 : total);
  } while (!atomic_compare_exchange_weak_explicit(axis, &old, next,
             memory_order_relaxed, memory_order_relaxed));
}

// Travel is consumed once, with no time division, dead zone or speed curve.
static inline void pg_swipe_consume(PGSwipeQueue *queue, float *x, float *y) {
  *x = atomic_exchange_explicit(&queue->x, 0, memory_order_relaxed) / 65536.0f;
  *y = atomic_exchange_explicit(&queue->y, 0, memory_order_relaxed) / 65536.0f;
}

static inline void pg_swipe_reset(PGSwipeQueue *queue) {
  atomic_store_explicit(&queue->x, 0, memory_order_relaxed);
  atomic_store_explicit(&queue->y, 0, memory_order_relaxed);
}
