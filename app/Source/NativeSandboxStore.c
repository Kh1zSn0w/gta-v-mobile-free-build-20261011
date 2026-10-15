#include "NativeSandboxSave.h"
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>

typedef struct {
    uint32_t magic, version;
    PGSandboxCheckpoint checkpoint;
    uint32_t checksum, reserved;
} PGCheckpointRecord;

static char checkpointPath[PATH_MAX];

bool pg_sandbox_checkpoint_valid(const PGSandboxCheckpoint *checkpoint) {
    return checkpoint && isfinite(checkpoint->x) && isfinite(checkpoint->y) &&
        isfinite(checkpoint->z) && isfinite(checkpoint->heading) &&
        fabsf(checkpoint->x) < 16000 && fabsf(checkpoint->y) < 16000 &&
        checkpoint->z > -1700 && checkpoint->z < 2700 &&
        checkpoint->heading >= 0 && checkpoint->heading < 360;
}

void pg_sandbox_store_configure(const char *filesRoot) {
    checkpointPath[0] = 0;
    if (!filesRoot || !*filesRoot) return;
    if (snprintf(checkpointPath, sizeof checkpointPath, "%s/sandbox-checkpoint.bin", filesRoot) >= (int)sizeof checkpointPath)
        checkpointPath[0] = 0;
}

static uint32_t recordChecksum(const PGCheckpointRecord *record) {
    const unsigned char *bytes = (const unsigned char *)record;
    uint32_t hash = 2166136261u;
    for (size_t i = 0; i < offsetof(PGCheckpointRecord, checksum); i++)
        hash = (hash ^ bytes[i]) * 16777619u;
    return hash;
}

static bool readRecord(const char *path, PGCheckpointRecord *record) {
    FILE *file = fopen(path, "rb");
    if (!file) return false;
    bool complete = fread(record, 1, sizeof *record, file) == sizeof *record && fgetc(file) == EOF;
    bool closed = fclose(file) == 0;
    return complete && closed && record->magic == 0x50475342 && record->version == 1 &&
        record->reserved == 0 && record->checksum == recordChecksum(record) &&
        pg_sandbox_checkpoint_valid(&record->checkpoint);
}

static bool writeRecord(const char *path, const PGCheckpointRecord *record) {
    char temporary[PATH_MAX];
    if (snprintf(temporary, sizeof temporary, "%s.tmp", path) >= (int)sizeof temporary) return false;
    FILE *file = fopen(temporary, "wb");
    if (!file) return false;
    bool written = fwrite(record, 1, sizeof *record, file) == sizeof *record;
    if (written) written = fflush(file) == 0 && fsync(fileno(file)) == 0;
    if (fclose(file) != 0) written = false;
    if (written) written = rename(temporary, path) == 0;
    if (!written) unlink(temporary);
    return written;
}

bool pg_sandbox_store_load(PGSandboxCheckpoint *checkpoint) {
    if (!checkpointPath[0] || !checkpoint) return false;
    PGCheckpointRecord record;
    char path[PATH_MAX];
    for (unsigned i = 0; i < 3; i++) {
        int length = i ? snprintf(path, sizeof path, "%s.%u", checkpointPath, i) :
            snprintf(path, sizeof path, "%s", checkpointPath);
        if (length < 0 || length >= (int)sizeof path) return false;
        if (readRecord(path, &record)) { *checkpoint = record.checkpoint; return true; }
    }
    return false;
}

bool pg_sandbox_store_write(const PGSandboxCheckpoint *checkpoint) {
    if (!checkpointPath[0] || !pg_sandbox_checkpoint_valid(checkpoint)) return false;
    char backup[PATH_MAX], older[PATH_MAX];
    if (snprintf(backup, sizeof backup, "%s.1", checkpointPath) >= (int)sizeof backup ||
        snprintf(older, sizeof older, "%s.2", checkpointPath) >= (int)sizeof older) return false;

    PGCheckpointRecord previous;
    // Never rotate a damaged current file over a valid recovery checkpoint.
    if (readRecord(checkpointPath, &previous)) {
        PGCheckpointRecord oldBackup;
        if (readRecord(backup, &oldBackup) && !writeRecord(older, &oldBackup)) return false;
        if (!writeRecord(backup, &previous)) return false;
    }
    PGCheckpointRecord record = {0};
    record.magic = 0x50475342;
    record.version = 1;
    record.checkpoint = *checkpoint;
    record.checksum = recordChecksum(&record);
    return writeRecord(checkpointPath, &record);
}
