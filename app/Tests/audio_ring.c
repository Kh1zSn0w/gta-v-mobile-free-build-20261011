#include "NativeAudioRing.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  float data[2048], left[1024] = {0}, right[1024] = {0};
  for (int i = 0; i < 1024; i++) { data[2*i] = .4f; data[2*i+1] = -.2f; }
  PGAudioPlayback state = {0};
  assert(pg_audio_render(&state, data, 1024, 0, 100, left, right, 128) == 0);
  assert(!state.primed && left[0] == 0);
  uint32_t read = pg_audio_render(&state, data, 1024, 0, 512, left, right, 128);
  assert(read == 128 && state.primed);
  assert(left[0] > 0 && left[0] < .4f);
  assert(left[64] == .4f && right[64] == -.2f);
  read = pg_audio_render(&state, data, 1024, read, 512, left, right, 512);
  assert(read == 512 && !state.primed);
  assert(fabsf(left[384]) < .4f && left[447] == 0);
  memset(left, 0, sizeof left); memset(right, 0, sizeof right);
  assert(pg_audio_render(&state, data, 1024, read, read + 127, left, right, 128) == read);
  // Wrapped counters still describe 512 contiguous frames.
  state = (PGAudioPlayback){0};
  read = UINT32_MAX - 255;
  assert(pg_audio_render(&state, data, 1024, read, read + 512, left, right, 128) == read + 128);
  assert(left[64] == .4f && right[64] == -.2f);
  state = (PGAudioPlayback){0};
  assert(pg_audio_render(&state, data, 1024, 0, 2048, left, right, 128) == 1152);
  state = (PGAudioPlayback){0};
  data[0] = NAN; data[1] = INFINITY;
  pg_audio_render(&state, data, 1024, 0, 1024, left, right, 128);
  assert(left[0] == 0 && right[0] == 0);
  // Normal playback preserves the mix exactly after the short resume fade.
  for (int i = 64; i < 128; i++) assert(left[i] == .4f && right[i] == -.2f);
  puts("Audio: stereo fidelity, jitter prebuffer, underrun recovery, counter wrap and invalid samples passed.");
}
