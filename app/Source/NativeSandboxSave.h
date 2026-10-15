#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float x, y, z, heading;
    uint64_t savedAt;
} PGSandboxCheckpoint;

// Checkpoints live beside the engine filesystem, outside Story's save files.
void pg_sandbox_store_configure(const char *filesRoot);
bool pg_sandbox_checkpoint_valid(const PGSandboxCheckpoint *checkpoint);
bool pg_sandbox_store_load(PGSandboxCheckpoint *checkpoint);
bool pg_sandbox_store_write(const PGSandboxCheckpoint *checkpoint);

bool PGSandboxSaveAvailable(void);
bool PGSandboxSaveRequest(void);
uint32_t PGSandboxSaveStatus(void);
