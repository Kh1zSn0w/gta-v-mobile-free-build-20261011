#pragma once
#include <math.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
  bool primed;
  uint32_t fadeIn;
  float lastLeft, lastRight;
} PGAudioPlayback;

// Real-time safe: no allocation, locks, logging or changes to the source mix.
static inline uint32_t pg_audio_render(PGAudioPlayback *state, const float *data,
    uint32_t capacity, uint32_t read, uint32_t write,
    float *left, float *right, uint32_t count) {
  if (!capacity || (capacity & (capacity - 1))) return read;
  uint32_t available = write - read;
  if (available > capacity) {
    read = write - capacity;
    available = capacity;
    state->primed = false;
  }
  if (!state->primed) {
    uint32_t prebuffer = capacity < 512 ? capacity : 512;
    if (available < prebuffer) return read;
    state->primed = true;
    state->fadeIn = 64;
  }
  uint32_t take = available < count ? available : count;
  for (uint32_t i = 0; i < take; i++) {
    uint32_t at = ((read + i) & (capacity - 1)) * 2;
    float l = isfinite(data[at]) ? data[at] : 0;
    float r = isfinite(data[at + 1]) ? data[at + 1] : 0;
    if (state->fadeIn) {
      float gain = (65 - state->fadeIn) / 64.0f;
      l *= gain; r *= gain;
      state->fadeIn--;
    }
    left[i] = l; right[i] = r;
    state->lastLeft = l; state->lastRight = r;
  }
  if (take < count) {
    // A short fade avoids the hard discontinuity caused by inserting silence
    // after an underrun. Re-prime before resuming instead of repeated clicks.
    uint32_t tail = count - take;
    if (tail > 64) tail = 64;
    for (uint32_t i = 0; i < tail; i++) {
      float gain = 1 - (i + 1) / (float)tail;
      left[take + i] = state->lastLeft * gain;
      right[take + i] = state->lastRight * gain;
    }
    state->lastLeft = state->lastRight = 0;
    state->primed = false;
  }
  return read + take;
}
