#include "NativeLocalReadCache.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static PGLocalReadCache cache = {.lock = PTHREAD_MUTEX_INITIALIZER};
static char sharedPath[PATH_MAX];
static void *reader(void *context) {
    unsigned offset = (unsigned)(uintptr_t)context;
    for (unsigned i = 0; i < 1000; ++i) {
        PGLocalReadHandle *held;
        int fd = pg_local_read_acquire(&cache, sharedPath, &held);
        assert(fd >= 0 && held);
        char value = 0;
        assert(pread(fd, &value, 1, offset) == 1 && value == (char)('a' + offset));
        pg_local_read_release(&cache, fd, held);
    }
    return NULL;
}
int main(void) {
    strcpy(sharedPath, "/tmp/gta-local-read-XXXXXX");
    int initial = mkstemp(sharedPath); assert(initial >= 0);
    assert(write(initial, "abcdefgh", 8) == 8); close(initial);
    pthread_t threads[8];
    for (unsigned i = 0; i < 8; ++i) assert(!pthread_create(&threads[i], NULL, reader, (void *)(uintptr_t)i));
    for (unsigned i = 0; i < 8; ++i) pthread_join(threads[i], NULL);
    unsigned occupied = 0;
    for (unsigned i = 0; i < PG_LOCAL_READ_HANDLES; ++i) {
        assert(!cache.slots[i].users);
        occupied += cache.slots[i].valid;
    }
    assert(occupied == 1);
    PGLocalReadHandle *held;
    assert(pg_local_read_acquire(&cache, "/does-not-exist/gta", &held) == -1 && !held);
    pg_local_read_close(&cache); unlink(sharedPath);
    puts("LOCAL ARCHIVE READ CACHE CHECKS PASSED");
}
