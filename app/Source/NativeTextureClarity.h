#pragma once
#include <stdint.h>

// Only filtered, repeating world textures. Keep shadow comparisons, point
// data samples and clamped UI/render-target samplers exactly as requested.
static inline uint32_t pg_texture_anisotropy(uint32_t filter, uint32_t s, uint32_t t,
                                            uint32_t original, uint32_t requested) {
  uint32_t current = (filter & 0x7f) == 0x55 ? (original < 1 ? 1 : original > 16 ? 16 : original) : 1;
  if ((filter & 0x80) || !(filter & 0x10) || s > 2 || t > 2) return current;
  uint32_t extra = requested == 4 || requested == 8 ? requested : 1;
  return current > extra ? current : extra;
}
