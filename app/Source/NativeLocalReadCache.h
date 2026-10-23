#pragma once
#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <errno.h>

// The game reads small ranges from the same local archives thousands of times.
// Cache descriptors only; pread keeps independent engine workers from sharing a cursor.
#define PG_LOCAL_READ_HANDLES 16
typedef struct {
    int fd;
    unsigned users;
    uint64_t stamp;
    bool valid;
    char path[PATH_MAX];
} PGLocalReadHandle;
typedef struct {
    pthread_mutex_t lock;
    uint64_t clock;
    PGLocalReadHandle slots[PG_LOCAL_READ_HANDLES];
} PGLocalReadCache;

static inline int pg_local_read_acquire(PGLocalReadCache *cache, const char *path, PGLocalReadHandle **held) {
    *held = NULL;
    if (!path || strlen(path) >= PATH_MAX) { errno = ENAMETOOLONG; return -1; }
    pthread_mutex_lock(&cache->lock);
    PGLocalReadHandle *oldest = NULL;
    for (unsigned i = 0; i < PG_LOCAL_READ_HANDLES; ++i) {
        PGLocalReadHandle *item = &cache->slots[i];
        if (item->valid && !strcmp(item->path, path)) {
            ++item->users; item->stamp = ++cache->clock; *held = item;
            int fd = item->fd;
            pthread_mutex_unlock(&cache->lock);
            return fd;
        }
        if (!item->users && (!oldest || !item->valid || (oldest->valid && item->stamp < oldest->stamp))) oldest = item;
    }
    int fd = open(path, O_RDONLY);
    if (fd >= 0 && oldest) {
        if (oldest->valid) close(oldest->fd);
        *oldest = (PGLocalReadHandle){.fd = fd, .users = 1, .stamp = ++cache->clock, .valid = true};
        strcpy(oldest->path, path); *held = oldest;
    }
    // When all slots are busy, this request owns its descriptor until release.
    pthread_mutex_unlock(&cache->lock);
    return fd;
}
static inline void pg_local_read_release(PGLocalReadCache *cache, int fd, PGLocalReadHandle *held) {
    if (!held) { if (fd >= 0) close(fd); return; }
    pthread_mutex_lock(&cache->lock);
    --held->users;
    pthread_mutex_unlock(&cache->lock);
}
// Only after all worker reads have stopped (used by the regression probe).
static inline void pg_local_read_close(PGLocalReadCache *cache) {
    pthread_mutex_lock(&cache->lock);
    for (unsigned i = 0; i < PG_LOCAL_READ_HANDLES; ++i) {
        PGLocalReadHandle *item = &cache->slots[i];
        if (item->valid && !item->users) { close(item->fd); item->valid = false; }
    }
    pthread_mutex_unlock(&cache->lock);
}
