#include "NativePackedAssetCache.h"
#include "NativeAssetReadCache.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
static PGAssetReadCache readers={.lock=PTHREAD_MUTEX_INITIALIZER};
static char dataPath[256],mapPath[256];
static void *reader(void *unused) {
 (void)unused;uint8_t bytes[137];
 for(unsigned i=0;i<1000;i++) {assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,17,bytes,sizeof bytes)==sizeof bytes);for(unsigned n=0;n<sizeof bytes;n++)assert(bytes[n]==(uint8_t)(n+17));}
 return NULL;
}
static void checkHintRanges(const char *dir) {
 char data[256],map[256];snprintf(data,sizeof data,"%s/hint-data",dir);snprintf(map,sizeof map,"%s/hint-map",dir);
 const size_t prefix=1024*1024,size=prefix+4096;
 uint8_t *source=calloc(1,prefix);assert(source);
 PGPackedAssetCache writer;assert(pg_packed_open(&writer,data,map,size));
 assert(pg_packed_store(&writer,0,source,prefix));
 bool warmed=true;
 // The first megabyte may be present while the rest of the same hint is not.
 // Advising the prefix must never hide an unpublished tail from demand fills.
 assert(!pg_asset_read_hint(&readers,2,data,map,size,0,size,true,&warmed));
 assert(!warmed);
 assert(pg_asset_read_hint(&readers,2,data,map,size,0,prefix,false,&warmed));assert(!warmed);
 assert(pg_packed_store(&writer,prefix,source,4096));
 assert(pg_asset_read_hint(&readers,2,data,map,size,0,size,true,&warmed));
 warmed=true;assert(!pg_asset_read_hint(&readers,2,data,map,size,size,1,true,&warmed));assert(!warmed);
 assert(!pg_asset_read_hint(&readers,2,data,map,size,0,0,true,&warmed));
 pg_packed_close(&writer);free(source);unlink(data);unlink(map);
}
int main(void) {
 char dir[]="/tmp/pg-read-cache-XXXXXX";assert(mkdtemp(dir));
 snprintf(dataPath,sizeof dataPath,"%s/data",dir);snprintf(mapPath,sizeof mapPath,"%s/map",dir);
 PGPackedAssetCache writer;assert(pg_packed_open(&writer,dataPath,mapPath,8192));
 uint8_t source[4096],bytes[200];for(unsigned i=0;i<sizeof source;i++)source[i]=(uint8_t)i;
 assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,0,bytes,sizeof bytes)==-1);
 assert(!pg_asset_read_warm(&readers,1,dataPath,mapPath,8192,0,4096));
 assert(pg_packed_store(&writer,0,source,4096));
 assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,17,bytes,137)==137 && !memcmp(bytes,source+17,137));
 assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,4090,bytes,20)==-1);
 assert(pg_packed_store(&writer,4096,source,4096));
 assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,4090,bytes,20)==20);
 assert(pg_asset_read_cached(&readers,1,dataPath,mapPath,8192,8191,bytes,2)==-1);
 pthread_t workers[6];for(unsigned i=0;i<6;i++)assert(!pthread_create(&workers[i],NULL,reader,NULL));for(unsigned i=0;i<6;i++)assert(!pthread_join(workers[i],NULL));
 // Every entry can be busy: refuse rather than closing an in-use descriptor.
 PGAssetReadHandle *held[64];for(unsigned i=0;i<64;i++){held[i]=pg_asset_read_acquire(&readers,100+i,dataPath,mapPath,8192);assert(held[i]);}
 assert(!pg_asset_read_acquire(&readers,200,dataPath,mapPath,8192));
 pg_asset_read_release(&readers,held[0]);assert(pg_asset_read_cached(&readers,200,dataPath,mapPath,8192,17,bytes,137)==137);
 for(unsigned i=1;i<64;i++)pg_asset_read_release(&readers,held[i]);
 checkHintRanges(dir);
 pg_asset_read_cache_close(&readers);pg_packed_close(&writer);unlink(dataPath);unlink(mapPath);rmdir(dir);
 puts("LOCAL STREAMING CACHE CHECKS PASSED: exact bytes, new published ranges, full hint coverage, holes, bounds, six concurrent readers and bounded busy-safe eviction.");
}
