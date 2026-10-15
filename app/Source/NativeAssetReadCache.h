#pragma once
#include <pthread.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>
#include <string.h>

// Keep only descriptors, never whole game archives. Busy entries cannot be
// evicted. Read-only bitmaps are read with pread so writer repair is safe.
#define PG_ASSET_READ_HANDLES 64
typedef struct { int dataFD,mapFD; uint32_t id,users; uint64_t size,stamp; bool valid; char dataPath[PATH_MAX],mapPath[PATH_MAX]; } PGAssetReadHandle;
typedef struct { pthread_mutex_t lock; uint64_t clock; PGAssetReadHandle slots[PG_ASSET_READ_HANDLES]; } PGAssetReadCache;
static inline void pg_asset_read_cache_init(PGAssetReadCache *cache) {
    *cache=(PGAssetReadCache){.lock=PTHREAD_MUTEX_INITIALIZER};
}
static inline PGAssetReadHandle *pg_asset_read_acquire(PGAssetReadCache *cache,uint32_t id,
        const char *dataPath,const char *mapPath,uint64_t size) {
    if (!size || size>INT64_MAX || !dataPath || !mapPath || strlen(dataPath)>=PATH_MAX || strlen(mapPath)>=PATH_MAX) return NULL;
    pthread_mutex_lock(&cache->lock);
    PGAssetReadHandle *slot=NULL;
    for(unsigned i=0;i<PG_ASSET_READ_HANDLES;i++) {
        PGAssetReadHandle *item=&cache->slots[i];
        if(item->valid && item->id==id && item->size==size && !strcmp(item->dataPath,dataPath) && !strcmp(item->mapPath,mapPath)) {
            item->users++; item->stamp=++cache->clock; pthread_mutex_unlock(&cache->lock); return item;
        }
        if(!item->users && (!slot || !item->valid || (slot->valid && item->stamp<slot->stamp))) slot=item;
    }
    if(!slot) { pthread_mutex_unlock(&cache->lock); return NULL; }
    if(slot->valid) { close(slot->dataFD);close(slot->mapFD);slot->valid=false; }
    int dataFD=open(dataPath,O_RDONLY),mapFD=dataFD<0?-1:open(mapPath,O_RDONLY);
    struct stat a,b; uint64_t mapBytes=(((size+4095)/4096)+7)/8;
    if(dataFD<0 || mapFD<0 || fstat(dataFD,&a) || fstat(mapFD,&b) || (uint64_t)a.st_size!=size || (uint64_t)b.st_size!=mapBytes) {
        if(dataFD>=0)close(dataFD);
        if(mapFD>=0)close(mapFD);
        pthread_mutex_unlock(&cache->lock);return NULL;
    }
    *slot=(PGAssetReadHandle){.dataFD=dataFD,.mapFD=mapFD,.id=id,.users=1,.size=size,.stamp=++cache->clock,.valid=true};
    strcpy(slot->dataPath,dataPath);strcpy(slot->mapPath,mapPath);
    pthread_mutex_unlock(&cache->lock);return slot;
}
static inline void pg_asset_read_release(PGAssetReadCache *cache,PGAssetReadHandle *slot) {
    pthread_mutex_lock(&cache->lock);slot->users--;pthread_mutex_unlock(&cache->lock);
}
static inline bool pg_asset_read_present(const PGAssetReadHandle *slot,uint64_t offset,size_t length) {
    if(!length || offset>slot->size || length>slot->size-offset)return false;
    uint64_t first=offset/4096,last=(offset+length-1)/4096,firstByte=first/8,lastByte=last/8;
    for(uint64_t at=firstByte;at<=lastByte;) {
        uint8_t bits[256];size_t wanted=(size_t)(lastByte-at+1);if(wanted>sizeof bits)wanted=sizeof bits;
        size_t done=0;while(done<wanted) {ssize_t n=pread(slot->mapFD,bits+done,wanted-done,(off_t)(at+done));if(n<0&&errno==EINTR)continue;if(n<=0)return false;done+=(size_t)n;}
        for(size_t i=0;i<wanted;i++) {
            uint64_t byte=at+i;unsigned lo=byte==firstByte?(unsigned)(first%8):0,hi=byte==lastByte?(unsigned)(last%8):7;
            unsigned mask=((1u<<(hi+1))-1)&~((1u<<lo)-1);if((bits[i]&mask)!=mask)return false;
        }
        at+=wanted;
    }
    return true;
}
static inline int64_t pg_asset_read_cached(PGAssetReadCache *cache,uint32_t id,const char *dataPath,
        const char *mapPath,uint64_t size,uint64_t offset,void *destination,size_t length) {
    if(offset>size || length>size-offset || (!destination&&length))return -1;
    if(!length)return 0;
    PGAssetReadHandle *slot=pg_asset_read_acquire(cache,id,dataPath,mapPath,size);if(!slot)return -1;
    int64_t result=-1;
    if(pg_asset_read_present(slot,offset,length)) {
        size_t done=0;while(done<length) {
            ssize_t n=pread(slot->dataFD,(uint8_t *)destination+done,length-done,(off_t)(offset+done));
            if(n<0&&errno==EINTR)continue;
            if(n<=0)break;
            done+=(size_t)n;
        }
        if(done==length)result=(int64_t)done;
    }
    pg_asset_read_release(cache,slot);return result;
}
// Hints share the demand reader's descriptors and check the complete requested
// range once. A failed disk advisory does not turn cached bytes into a miss.
static inline bool pg_asset_read_hint(PGAssetReadCache *cache,uint32_t id,const char *dataPath,
        const char *mapPath,uint64_t size,uint64_t offset,size_t length,bool warm,bool *warmed) {
    if(warmed)*warmed=false;
    if(offset>=size || !length)return false;
    if(length>size-offset)length=(size_t)(size-offset);
    PGAssetReadHandle *slot=pg_asset_read_acquire(cache,id,dataPath,mapPath,size);if(!slot)return false;
    bool present=pg_asset_read_present(slot,offset,length);
#if defined(__APPLE__) && defined(F_RDADVISE)
    if(present && warm) {
        size_t warmLength=length>1024*1024?1024*1024:length;
        struct radvisory advice={(off_t)offset,(int)warmLength};
        bool accepted=fcntl(slot->dataFD,F_RDADVISE,&advice)==0;
        if(warmed)*warmed=accepted;
    }
#else
    // Tests verify the published-range gate without reading uncached sparse bytes.
    (void)warm;
#endif
    pg_asset_read_release(cache,slot);return present;
}
static inline bool pg_asset_read_warm(PGAssetReadCache *cache,uint32_t id,const char *dataPath,
        const char *mapPath,uint64_t size,uint64_t offset,size_t length) {
    if(length>1024*1024)length=1024*1024;
    bool warmed=false;
    bool present=pg_asset_read_hint(cache,id,dataPath,mapPath,size,offset,length,true,&warmed);
#if defined(__APPLE__) && defined(F_RDADVISE)
    return present && warmed;
#else
    return present;
#endif
}
static inline void pg_asset_read_cache_close(PGAssetReadCache *cache) {
    pthread_mutex_lock(&cache->lock);
    for(unsigned i=0;i<PG_ASSET_READ_HANDLES;i++) if(cache->slots[i].valid && !cache->slots[i].users) {
        close(cache->slots[i].dataFD);close(cache->slots[i].mapFD);cache->slots[i].valid=false;
    }
    pthread_mutex_unlock(&cache->lock);
}
