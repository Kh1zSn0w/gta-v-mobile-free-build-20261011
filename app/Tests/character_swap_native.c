// Execute the actual generated CHANGE_PLAYER_MODEL body. Only its external
// engine boundaries are stubbed, so a missing-task dereference cannot be hidden
// by replacing the entire model-change native with an always-successful stub.
#include "NativeCharacterSwap.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint32_t u32;
typedef uint64_t u64;
typedef struct { unsigned char bytes[16]; } v128;
typedef struct { uint8_t *data; uint64_t size; } Memory;
typedef void (*Function)(void);
typedef struct { Function func; void *module_instance; } Entry;
typedef struct {
    uint64_t w2c_g0;
    Memory *w2c_env_memory;
    struct { Entry data[8]; } w2c_0x5F_indirect_function_table;
} w2c_game;

#define FUNC_PROLOGUE ((void)0)
#define FUNC_EPILOGUE ((void)0)
#define UNREACHABLE assert(!"Unexpected native task assertion")
#define CALL_INDIRECT(table,type,signature,index,...) ((type)(table).data[index].func)(__VA_ARGS__)
#define checked_add_u64(a,b) ((a)+(b))
static void memory_read(Memory *memory,u64 at,void *out,size_t bytes) {
    assert(at<=memory->size && bytes<=memory->size-at);memcpy(out,memory->data+at,bytes);
}
static void memory_write(Memory *memory,u64 at,const void *value,size_t bytes) {
    assert(at<=memory->size && bytes<=memory->size-at);memcpy(memory->data+at,value,bytes);
}
#define LOAD(name,type) static type name(int unusedA,int unusedB,Memory *memory,u64 at){(void)unusedA;(void)unusedB;type value;memory_read(memory,at,&value,sizeof value);return value;}
#define STORE(name,type) static void name(int unusedA,int unusedB,Memory *memory,u64 at,type value){(void)unusedA;(void)unusedB;memory_write(memory,at,&value,sizeof value);}
// Generated unused base/size parameters are pointer/integer in the real runtime.
// These test macros drop those parameters without changing load/store semantics.
LOAD(read32,u32) LOAD(read16,uint16_t) LOAD(read64,u64) LOAD(read128,v128)
STORE(write32,u32) STORE(write16,uint16_t) STORE(write128,v128)
#define i32_load_shared(a,b,m,p) read32(0,0,m,p)
#define i32_load16_u_shared(a,b,m,p) read16(0,0,m,p)
#define i64_load_shared(a,b,m,p) read64(0,0,m,p)
#define v128_load_shared(a,b,m,p) read128(0,0,m,p)
#define i32_store_shared(a,b,m,p,v) write32(0,0,m,p,v)
#define i32_store16_shared(a,b,m,p,v) write16(0,0,m,p,v)
#define v128_store_shared(a,b,m,p,v) write128(0,0,m,p,v)

static Memory memory;
static bool preloaded;
static unsigned replacements,flushes,taskQueries,taskTransfers;
enum { OLD_PED=10000, NEW_PED=20000, INTELLIGENCE=40000, PRIMARY=50000,
    CONTROL=51000, PRIMARY_TABLE=60000, CONTROL_TABLE=61000, QUEUE_TABLE=62000,
    TRANSFORM_TABLE=63000, LEAF=70000 };
static bool pg_wardrobe_preloaded_swap(void) { return preloaded; }
static bool pg_wardrobe_script_handoff_ready(uint64_t ped) {
    return !preloaded || pg_character_task_handoff_ready(memory.data,memory.size,ped);
}
static void pointer(u64 at,u64 value) {memory_write(&memory,at,&value,8);}
static void count(u32 value) {memory_write(&memory,INTELLIGENCE+4064,&value,4);}
static void w2c_game_f5315(w2c_game *game,u32 unused) {(void)game;(void)unused;flushes++;}
static u32 w2c_game_f680(w2c_game *game,u32 unused,u64 text) {(void)game;(void)unused;(void)text;return 0;}
static void w2c_game_f681(w2c_game *game,u32 a,u32 b,u64 c) {(void)game;(void)a;(void)b;(void)c;}
static u64 w2c_game_f4633(w2c_game *game,u64 hash,u64 out) {(void)game;(void)hash;write16(0,0,&memory,out,0);return 0;}
static u64 w2c_game_f4634(w2c_game *game,u32 hash,u64 out) {(void)game;(void)hash;write16(0,0,&memory,out,0);return 0;}
static u64 w2c_game_f63815(w2c_game *game,u32 player) {(void)game;assert(player==0);return OLD_PED;}
static u64 w2c_game_f47995(w2c_game *game,u64 ped,u64 model) {(void)game;assert(ped==OLD_PED && model<memory.size);replacements++;return NEW_PED;}
static void w2c_game_f46445(w2c_game *game,u64 transform) {(void)game;assert(transform==NEW_PED+240);}
static u64 w2c_game_f45797(w2c_game *game,u64 ped,u32 create) {
    (void)game;assert(ped==NEW_PED && create==1);
    assert(pg_character_task_handoff_ready(memory.data,memory.size,ped));
    taskQueries++;return CONTROL;
}
static void transform(void *game,u64 address,u64 vector) {(void)game;assert(address==NEW_PED+240 && vector<memory.size);}
static u64 subtask(void *game,u64 task) {(void)game;assert(task==CONTROL);return LEAF;}
static void transfer(void *game,u64 primary,u64 child,u32 priority,u32 unused) {(void)game;assert(primary==PRIMARY && child==LEAF && priority==4 && unused==0);taskTransfers++;}
static void drain(void *game,u64 queue) {(void)game;assert(queue==INTELLIGENCE+4024);}

#include "../Build/Probe/character-change-native.inc"

int main(void) {
    memory=(Memory){calloc(1,1024*1024),1024*1024};assert(memory.data);
    w2c_game game={.w2c_g0=900000,.w2c_env_memory=&memory};
    game.w2c_0x5F_indirect_function_table.data[1]=(Entry){(Function)transform,&game};
    game.w2c_0x5F_indirect_function_table.data[2]=(Entry){(Function)subtask,&game};
    game.w2c_0x5F_indirect_function_table.data[3]=(Entry){(Function)transfer,&game};
    game.w2c_0x5F_indirect_function_table.data[4]=(Entry){(Function)drain,&game};
    pointer(NEW_PED+240,TRANSFORM_TABLE);pointer(TRANSFORM_TABLE+16,1);
    pointer(NEW_PED+4320,INTELLIGENCE);
    pointer(INTELLIGENCE+4032,PRIMARY);pointer(PRIMARY,PRIMARY_TABLE);pointer(PRIMARY_TABLE+24,3);
    pointer(INTELLIGENCE+4056,CONTROL);pointer(CONTROL,CONTROL_TABLE);pointer(CONTROL_TABLE+584,2);
    pointer(INTELLIGENCE+4024,QUEUE_TABLE);pointer(QUEUE_TABLE+16,4);

    // Sandbox may have one primary task but no fourth scripted-control task.
    preloaded=true;count(1);pointer(INTELLIGENCE+4056,0);
    for(unsigned model=1;model<=15;model++) {
        w2c_game_f58625(&game,0,model);
        assert(replacements==model && !flushes && !taskQueries && !taskTransfers && game.w2c_g0==900000);
    }
    // Also exercise the post-replacement state with no primary script task.
    count(0);pointer(INTELLIGENCE+4032,0);
    w2c_game_f58625(&game,0,16);assert(replacements==16 && !taskQueries && game.w2c_g0==900000);
    count(4);pointer(INTELLIGENCE+4032,PRIMARY);pointer(INTELLIGENCE+4056,CONTROL);
    w2c_game_f58625(&game,0,17);assert(replacements==17 && taskQueries==1 && taskTransfers==1 && !flushes && game.w2c_g0==900000);
    preloaded=false;
    w2c_game_f58625(&game,0,18);assert(replacements==18 && taskQueries==2 && taskTransfers==2 && flushes==1 && game.w2c_g0==900000);
    assert(!pg_character_task_handoff_ready(memory.data,memory.size,UINT64_MAX));
    free(memory.data);
    puts("CHARACTER NATIVE CHECKS PASSED: actual generated model-change body, all preset routes, missing control/primary tasks, valid task transfer, original path and stack restoration.");
}
