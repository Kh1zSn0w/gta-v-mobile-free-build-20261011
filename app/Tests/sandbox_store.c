#include "NativeSandboxSave.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char directory[] = "/tmp/pg-sandbox-save.XXXXXX";
    assert(mkdtemp(directory));
    pg_sandbox_store_configure(directory);
    PGSandboxCheckpoint loaded, first = {100, -200, 42, 270, 1000};
    assert(!pg_sandbox_store_load(&loaded));
    assert(pg_sandbox_store_write(&first));
    assert(pg_sandbox_store_load(&loaded) && loaded.x == 100 && loaded.savedAt == 1000);
    PGSandboxCheckpoint second = first; second.x = 222;
    assert(pg_sandbox_store_write(&second));
    PGSandboxCheckpoint third = first; third.x = 333;
    assert(pg_sandbox_store_write(&third));
    char path[1024]; snprintf(path, sizeof path, "%s/sandbox-checkpoint.bin", directory);
    FILE *file = fopen(path, "wb"); assert(file); fputs("interrupted write", file); fclose(file);
    assert(pg_sandbox_store_load(&loaded) && loaded.x == 222);
    // An invalid new snapshot cannot overwrite the last usable recovery file.
    PGSandboxCheckpoint invalid = first; invalid.x = NAN;
    assert(!pg_sandbox_store_write(&invalid));
    assert(pg_sandbox_store_load(&loaded) && loaded.x == 222);
    invalid = first; invalid.heading = 360; assert(!pg_sandbox_store_write(&invalid));
    assert(pg_sandbox_store_write(&third));
    assert(pg_sandbox_store_load(&loaded) && loaded.x == 333);
    unlink(path);
    snprintf(path, sizeof path, "%s/sandbox-checkpoint.bin.1", directory); unlink(path);
    snprintf(path, sizeof path, "%s/sandbox-checkpoint.bin.2", directory); unlink(path);
    rmdir(directory);
    puts("SANDBOX STORE CHECKS PASSED: durable atomic publish, two backups, corruption recovery and invalid-state rejection.");
}
