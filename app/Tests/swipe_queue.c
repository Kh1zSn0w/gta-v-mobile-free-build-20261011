#include "NativeSwipeLook.h"
#include "NativeTextureClarity.h"
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
  pg_swipe_consume(&queue, &x, &y);
  assert(x == 15 && y == 0);
  pg_swipe_consume(&queue, &x, &y);
  assert(x == 0 && y == 0);
  pg_swipe_add_axis(&queue.x, 1.0f / 1024);
  pg_swipe_consume(&queue, &x, &y);
  assert(x == 1.0f / 1024);
  pg_swipe_add_axis(&queue.x, NAN);
  pg_swipe_add_axis(&queue.y, INFINITY);
  assert(atomic_load(&queue.x) == 0 && atomic_load(&queue.y) == 0);
  pg_swipe_add_axis(&queue.y, -8);
  pg_swipe_consume(&queue, &x, &y);
  assert(x == 0 && y == -8);
  pthread_t threads[4];
  for (int i = 0; i < 4; i++) assert(pthread_create(&threads[i], NULL, produce, NULL) == 0);
  for (int i = 0; i < 4; i++) pthread_join(threads[i], NULL);
  assert(atomic_load(&queue.x) == 1000 * 65536);
  pg_swipe_reset(&queue);
  assert(atomic_load(&queue.x) == 0);
  for (int i = 0; i < 100; i++) pg_swipe_add_axis(&queue.x, 4096);
  assert(atomic_load(&queue.x) == 536870912);
  assert(pg_texture_anisotropy(0x15, 1, 1, 1, 4) == 4);
  assert(pg_texture_anisotropy(0x15, 1, 1, 1, 8) == 8);
  assert(pg_texture_anisotropy(0x15, 1, 1, 1, 0) == 1);
  assert(pg_texture_anisotropy(0x55, 1, 1, 16, 4) == 16);
  assert(pg_texture_anisotropy(0x95, 1, 1, 1, 8) == 1);
  assert(pg_texture_anisotropy(0, 1, 1, 1, 8) == 1);
  assert(pg_texture_anisotropy(0x15, 3, 3, 1, 8) == 1);
  puts("Direct travel queue: subpixel, concurrent, once-only, cancellation and bounds passed. Texture filtering preserves shadows, point samples and UI.");
}
