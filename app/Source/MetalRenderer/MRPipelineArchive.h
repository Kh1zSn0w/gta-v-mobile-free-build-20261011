#pragma once
#import <Metal/Metal.h>

namespace mr {
void pipelineArchiveConfigure(id<MTLDevice> device);
void pipelineArchiveApply(MTLRenderPipelineDescriptor *descriptor);
void pipelineArchiveRecord(MTLRenderPipelineDescriptor *descriptor);
}
