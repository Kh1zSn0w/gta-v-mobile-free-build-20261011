#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void PGCaptureNativeFrame(const char *name);
double PGRenderedFramesPerSecond(void);
void PGAttachMetalLayer(void *layer);
void PGStartGraphics(void *memory,uint64_t memorySize,uint64_t ring,uint64_t ringSize,uint64_t debug);
// Configure before starting the engine: 0 original, 4 or 8 anisotropic filtering.
void PGSetTextureClarity(uint32_t amount);
#ifdef __cplusplus
}
#endif
