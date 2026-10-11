#include "NativeSwipeLook.h"
#include <assert.h>
#include <pthread.h>
#include <stdio.h>

static PGSwipeQueue queue;
static void *produce(void *ignored) {
  for (int i = 0; i < 1000; i++) pg_swipe_add_axis(&queue.x, 0.25f);
  return NULL;
}
int main(void) {
  float x, y;
  pg_swipe_add_axis(&queue.x, 10);
  pg_swipe_add_axis(&queue.x, 5);
  // Neutral virtual-pad publication must not touch the independent queue.
  pg_swipe_consume(&queue, 1.0 / 60, &x, &y);
  assert(x > 1 && y == 0);
  pg_swipe_consume(&queue, 1.0 / 60, &x, &y);
  assert(x == 0 && y == 0);
  assert(fabsf(pg_swipe_axis(4 * 256, 1.0 / 120) -
               pg_swipe_axis(8 * 256, 1.0 / 60)) < .00001f);
  pg_swipe_add_axis(&queue.x, NAN);
  pg_swipe_add_axis(&queue.y, INFINITY);
  assert(atomic_load(&queue.x) == 0 && atomic_load(&queue.y) == 0);
  pg_swipe_add_axis(&queue.y, -8);
  pg_swipe_consume(&queue, 1.0 / 60, &x, &y);
  assert(x == 0 && y < -1);
  pthread_t threads[4];
  for (int i = 0; i < 4; i++) assert(pthread_create(&threads[i], NULL, produce, NULL) == 0);
  for (int i = 0; i < 4; i++) pthread_join(threads[i], NULL);
  assert(atomic_load(&queue.x) == 1000 * 256);
  pg_swipe_reset(&queue);
  assert(atomic_load(&queue.x) == 0);
  for (int i = 0; i < 100; i++) pg_swipe_add_axis(&queue.x, 4096);
  assert(atomic_load(&queue.x) == 2097152);
  pg_swipe_consume(&queue, 0.1, &x, &y);
  assert(x == 8 && y == 0);
  assert(pg_swipe_pad_axis(.001f) > .25f);
  assert(pg_swipe_pad_axis(8) == 1);
  assert(pg_swipe_boost_value(4, -3, 12, 4125, 0, 1) == 4);
  assert(pg_swipe_boost_value(4, -3, 12, 4123, 0, 1) == 3);
  assert(pg_swipe_boost_value(-4, 3, 12, 4124, 0, 1) == 4);
  assert(pg_swipe_boost_value(-4, 3, 12, 4122, 0, 1) == 3);
  assert(pg_swipe_boost_value(-4, 3, 12, 4098, 0, -1) == -4);
  assert(pg_swipe_boost_value(-4, 3, 12, 4099, 0, -1) == -3);
  assert(pg_swipe_boost_value(0, 0, 12, 4125, 0, .5f) == .5f);
  assert(pg_swipe_boost_value(4, 3, 12, 4096, 0, .5f) == .5f);
  assert(pg_swipe_boost_value(4, 3, 12, 4125, 1, .5f) == .5f);
  assert(pg_swipe_boost_value(4, 3, 9, 4125, 0, .5f) == .5f);
  assert(pg_swipe_boost_value(4, 3, 12, 4124, 0, .5f) == .5f);
  assert(pg_swipe_boost_value(4, 3, 12, 4098, 0, -.5f) == -.5f);
  assert(pg_swipe_boost_value(4, 3, 12, 4125, 0, 0) == 0);
  assert(pg_swipe_boost_value(20, 3, 12, 4125, 0, 1) == 8);
  puts("Swipe queue: concurrent producers, once-only delivery, FPS normalization, cancellation and bounds passed.");
}
