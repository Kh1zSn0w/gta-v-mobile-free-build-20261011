#pragma once
#include "NativeTouchContext.h"

// The optional script-task handoff reads slot 3, not just the primary task.
// Sandbox may have a primary task without that scripted-control slot.
static inline bool pg_character_task_handoff_ready(const uint8_t *memory,uint64_t size,uint64_t ped) {
    uint64_t intelligence=0,primary=0,control=0,primaryTable=0,controlTable=0,queueTable=0;
    uint32_t count=0;
    return ped && ped<=size && size-ped>=6464 &&
        pg_context_u64(memory,size,ped+4320,&intelligence) && intelligence &&
        intelligence<=size && size-intelligence>=6424 &&
        pg_context_u32(memory,size,intelligence+4064,&count) && count>3 &&
        pg_context_u64(memory,size,intelligence+4032,&primary) && primary &&
        pg_context_u64(memory,size,intelligence+4056,&control) && control &&
        pg_context_u64(memory,size,primary,&primaryTable) && primaryTable &&
        primaryTable<=size && size-primaryTable>=32 &&
        pg_context_u64(memory,size,control,&controlTable) && controlTable &&
        controlTable<=size && size-controlTable>=592 &&
        pg_context_u64(memory,size,intelligence+4024,&queueTable) && queueTable &&
        queueTable<=size && size-queueTable>=24;
}
