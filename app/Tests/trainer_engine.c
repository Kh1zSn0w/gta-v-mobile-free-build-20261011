#include "NativeTrainer.h"
#include "NativeTouchContext.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
typedef uint32_t u32;
typedef uint64_t u64;
typedef struct { uint64_t w2c_g0; } w2c_game;
static struct { struct { uint8_t *data; uint64_t size; } memory; } env;
static double now;
static bool paused;
static double timeMS(int clock) { (void)clock; return now * 1000; }
static bool PGPauseMenuActive(void) { return paused; }
static void pg_log(const char *message) { (void)message; }
static int configuredStartMode=2;
static _Atomic uint64_t virtualPad = 0x0000808080800000ull;
#include "TrainerEngine.inc"
static int called, count;
static u32 hour, minute, second;
#define CHEAT(number) void w2c_game_f##number(w2c_game *game) { (void)game; called=number; count++; }
CHEAT(37634) CHEAT(37635) CHEAT(37636) CHEAT(37638) CHEAT(37639)
CHEAT(37641) CHEAT(37644) CHEAT(37645) CHEAT(37646) CHEAT(37650)
void w2c_game_f49437(w2c_game *game, u32 h, u32 m, u32 s) {
    (void)game; called=49437; count++; hour=h; minute=m; second=s;
}
static char named[128];
static bool unknownWeather;
static uint32_t powerCalls[4], gravityHandle, gravityEnabled, currentVehicle, gravityLevel;
static float runMultiplier = 1, swimMultiplier = 1, velocity[3];
void w2c_game_f37642(w2c_game *g, u64 at, u32 spawn) { assert(g->w2c_g0 == at && spawn == 1); strcpy(named,(char *)env.memory.data+at); }
u32 w2c_game_f37934(w2c_game *g, u64 at) { (void)g; strcpy(named,(char *)env.memory.data+at); return unknownWeather ? UINT32_MAX : 0; }
void w2c_game_f52794(w2c_game *g, u64 at) { assert(g->w2c_g0 == at); assert(strcmp(named,(char *)env.memory.data+at)==0); }
CHEAT(52797) CHEAT(52798)
u32 w2c_game_f58714(w2c_game *g) { (void)g; return 0; }
u32 w2c_game_f58715(w2c_game *g) { (void)g; return 101; }
#define POWER(number,index) void w2c_game_f##number(w2c_game *g,u32 player) { (void)g; assert(player==0); powerCalls[index]++; }
POWER(53010,0) POWER(53009,1) POWER(53007,2) POWER(53008,3)
void w2c_game_f58753(w2c_game *g,u32 p,float m) { (void)g; assert(p==0); swimMultiplier=m; }
void w2c_game_f58754(w2c_game *g,u32 p,float m) { (void)g; assert(p==0); runMultiplier=m; }
void w2c_game_f58646(w2c_game *g,u32 p) { (void)g; assert(p==0); }
void w2c_game_f58699(w2c_game *g,u32 p) { (void)g; assert(p==0); }
void w2c_game_f58779(w2c_game *g,u32 p,u32 b,u32 a) { (void)g; assert(p==0 && b==0 && a==0); }
u32 w2c_game_f57184(w2c_game *g,u32 ped,u32 last) { (void)g; assert(ped==101 && last==0); return currentVehicle; }
void w2c_game_f61578(w2c_game *g,u32 vehicle) { (void)g; assert(vehicle==currentVehicle); called=61578; }
void w2c_game_f50154(w2c_game *g,u32 ped,u64 at) { assert(g->w2c_g0==at && ped==101); for(int i=0;i<3;i++) memcpy(&velocity[i],env.memory.data+at+i*8,4); }
void w2c_game_f50156(w2c_game *g,u32 ped,u32 enabled) { (void)g; gravityHandle=ped; gravityEnabled=enabled; }
float w2c_game_f50032(w2c_game *g,u32 ped) { (void)g; assert(ped==101); return 0; }
void w2c_game_f52941(w2c_game *g,u32 level) { (void)g; gravityLevel=level; }
static void request(w2c_game *game,u32 command) { assert(PGTrainerRequest(command)); pg_trainer_tick(game); assert(game->w2c_g0==31000000); }
#include "wardrobe_fixture.inc"
static void pointer(uint64_t address, uint64_t value) { memcpy(env.memory.data+address, &value, 8); }
static PGSandboxCheckpoint fixturePosition={100,-200,42,270,0};
static bool fixtureFrozen,fixtureCollision=true;
void w2c_game_f50028(w2c_game *g,u64 at,u32 handle,u32 alive) {
    (void)g;assert(handle==101 && alive==1);
    memcpy(env.memory.data+at,&fixturePosition.x,4);
    memcpy(env.memory.data+at+8,&fixturePosition.y,4);
    memcpy(env.memory.data+at+16,&fixturePosition.z,4);
}
void w2c_game_f60328(w2c_game *g,u64 at) {(void)g;assert(at<env.memory.size-24);}
void w2c_game_f50133(w2c_game *g,u32 handle,u64 at,u32 tasks,u32 ik,u32 warp) {
    (void)g;assert(handle==101 && !tasks && !ik && warp);
    memcpy(&fixturePosition.x,env.memory.data+at,4);
    memcpy(&fixturePosition.y,env.memory.data+at+8,4);
    memcpy(&fixturePosition.z,env.memory.data+at+16,4);
}
void w2c_game_f50135(w2c_game *g,u32 handle,float heading) {(void)g;assert(handle==101);fixturePosition.heading=heading;}
void w2c_game_f50102(w2c_game *g,u32 handle,u32 frozen) {(void)g;assert(handle==101);fixtureFrozen=frozen!=0;}
u32 w2c_game_f50141(w2c_game *g,u32 handle) {(void)g;assert(handle==101);return fixtureCollision;}
int main(void) {
    w2c_game game = {.w2c_g0=31000000};
    pg_trainer_tick(&game);
    assert(!PGTrainerReady());
    env.memory.size=32*1024*1024;
    env.memory.data=calloc(1,env.memory.size);
    assert(env.memory.data);
    pointer(20159720,30000000);
    pointer(30000008,30001000);
    pointer(30001000+4328,30000000);
    pointer(30001000+4320,30010000);
    pointer(30010000+4032,30018000);
    uint32_t scriptCount=1; memcpy(env.memory.data+30010000+4064,&scriptCount,4);
    pointer(19603008,30008000);
    pointer(26005240,30009000);
    float health=100;
    memcpy(env.memory.data+30001000+672,&health,4);
    pg_trainer_tick(&game);
    assert(PGTrainerReady());
    const int expected[] = {37635,37634,37638,37636,0,37639,37646,37650,37644,37641,37645,49437,49437,49437,49437};
    const u32 hours[] = {6,12,19,0};
    for(u32 command=1;command<=15;command++) {
        called=0; count=0;
        assert(PGTrainerRequest(command));
        assert(!PGTrainerRequest(command));
        assert(PGTrainerStatus()==PG_TRAINER_PENDING);
        pg_trainer_tick(&game);
        assert(PGTrainerStatus()==PG_TRAINER_HANDLED);
        assert(called==expected[command-1]);
        assert(count==(command==5?0:1));
        if(command>=12) assert(hour==hours[command-12] && minute==0 && second==0);
        pg_trainer_tick(&game);
        assert(count==(command==5?0:1));
    }
    assert(PGTrainerInvincible());
    assert(env.memory.data[20156136]==0 && env.memory.data[20156137]==1);
    assert(PGTrainerRequest(5)); pg_trainer_tick(&game); assert(!PGTrainerInvincible());
    assert(PGTrainerRequest(1)); paused=true; pg_trainer_tick(&game);
    assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE && !PGTrainerReady());
    paused=false; pg_trainer_tick(&game);
    assert(PGTrainerRequest(1)); now=6; count=0; pg_trainer_tick(&game);
    assert(PGTrainerStatus()==PG_TRAINER_EXPIRED && count==0);
    // Borrowed strings are on the engine stack and restored after every native.
    uint32_t weatherCount=12; memcpy(env.memory.data+19611536,&weatherCount,4);
    for(u32 c=34;c<=45;c++) { request(&game,c); assert(strcmp(named,trainerWeather[c-34])==0); assert(PGTrainerStatus()==PG_TRAINER_HANDLED); }
    unknownWeather=true; request(&game,43); assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE); unknownWeather=false;
    for(u32 c=46;c<=85;c++) { request(&game,c); assert(strcmp(named,trainerVehicles[c-46])==0); }
    uint64_t savedStack=game.w2c_g0; game.w2c_g0=64;
    assert(!pg_trainer_named(&game,"adder",true)); assert(game.w2c_g0==64); game.w2c_g0=savedStack;
    for(u32 c=16;c<=23;c++) { request(&game,c); assert(PGTrainerToggleState(c)); }
    assert(!PGTrainerToggleState(18) && PGTrainerToggleState(19));
    assert(runMultiplier==1.49f && swimMultiplier==1.49f);
    uint32_t before=powerCalls[0]; pg_trainer_tick(&game); assert(powerCalls[0]==before+1);
    request(&game,18); assert(PGTrainerToggleState(18) && !PGTrainerToggleState(19));
    request(&game,24); assert(gravityHandle==101 && gravityEnabled==0);
    atomic_store(&virtualPad,0x0000000000800080ull); // forward stick + Jump
    pg_trainer_tick(&game); assert(velocity[0]==0 && velocity[1]>11.9f && velocity[2]==8);
    atomic_store(&virtualPad,0x0000000080800200ull); // centred stick + Stealth
    pg_trainer_tick(&game); assert(velocity[0]==0 && velocity[1]==0 && velocity[2]==-8);
    request(&game,24); assert(gravityEnabled==1 && !PGTrainerToggleState(24));
    request(&game,30); assert(gravityLevel==1); request(&game,31); assert(gravityLevel==0);
    currentVehicle=0; request(&game,28); assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE);
    currentVehicle=202; request(&game,28); assert(called==61578);
    request(&game,29); assert(velocity[2]==35);
    request(&game,25); assert(atomic_load(&trainerToggles)==0 && runMultiplier==1 && swimMultiplier==1);
    memset(powerCalls,0,sizeof powerCalls); pg_trainer_tick(&game); assert(powerCalls[0]==0 && powerCalls[1]==0 && powerCalls[2]==0 && powerCalls[3]==0);
    request(&game,16); paused=true; pg_trainer_tick(&game); assert(PGTrainerToggleState(16)); paused=false; pg_trainer_tick(&game);
    health=0; memcpy(env.memory.data+30001000+672,&health,4); pg_trainer_tick(&game); assert(!PGTrainerToggleState(16));
    health=100; memcpy(env.memory.data+30001000+672,&health,4); pg_trainer_tick(&game);
    request(&game,20); request(&game,30);
    pointer(20159720,0); pg_trainer_tick(&game);
    assert(!PGTrainerReady() && !PGTrainerToggleState(20) && runMultiplier==1.49f);
    pointer(20159720,30000000); pg_trainer_tick(&game);
    assert(PGTrainerReady() && runMultiplier==1.0f && gravityLevel==0);
    for(int guard=0;guard<3;guard++) {
        if(guard==0) env.memory.data[28501281]=1;
        if(guard==1) env.memory.data[18581341]=1;
        if(guard==2) {health=0;memcpy(env.memory.data+30001000+672,&health,4);}
        pg_trainer_tick(&game); assert(!PGTrainerReady());
        assert(!PGTrainerRequest(1));
        env.memory.data[28501281]=env.memory.data[18581341]=0;
    }
    health=100; memcpy(env.memory.data+30001000+672,&health,4); now=20; pg_trainer_tick(&game);
    for(u32 c=86;c<=100;c++) {request(&game,c); assert(strcmp(named,wardrobePolice[c-86])==0);}
    assert(pg_wardrobe_hash("s_m_y_cop_01")==0x5e3da4a4u);
    configuredStartMode=1; pg_trainer_tick(&game); assert(!PGTrainerCommandAvailable(101));
    request(&game,101); assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE);
    configuredStartMode=2; pg_trainer_tick(&game); assert(PGTrainerCommandAvailable(101));
    fixtureLoaded=false; request(&game,101); assert(PGTrainerStatus()==PG_TRAINER_PENDING && fixtureModel==0x1234);
    now+=6; pg_trainer_tick(&game); assert(PGTrainerStatus()==PG_TRAINER_PENDING); // streaming may outlast the normal five-second command
    fixtureLoaded=true; pg_trainer_tick(&game); assert(PGTrainerStatus()==PG_TRAINER_PENDING); pg_trainer_tick(&game);
    assert(PGTrainerStatus()==PG_TRAINER_HANDLED && fixtureModel==0x5e3da4a4u);
    request(&game,101);assert(PGTrainerStatus()==PG_TRAINER_HANDLED && wardrobePendingModel==0);
    request(&game,115); pg_trainer_tick(&game); pg_trainer_tick(&game); assert(fixtureModel==0x1234);
    for(u32 c=101;c<=114;c++) {
        request(&game,c);pg_trainer_tick(&game);pg_trainer_tick(&game);
        assert(PGTrainerStatus()==PG_TRAINER_HANDLED && fixtureModel==pg_wardrobe_hash(wardrobeModels[c-101]));
    }
    request(&game,115);pg_trainer_tick(&game);pg_trainer_tick(&game);assert(fixtureModel==0x1234);
    fixtureLoaded=false; request(&game,101); now+=16; pg_trainer_tick(&game); assert(PGTrainerStatus()==PG_TRAINER_EXPIRED);
    fixtureLoaded=true; PGTrainerSelectClothingSlot(3); now+=1; pg_trainer_tick(&game);
    assert(((PGTrainerClothingState(3)>>16)&65535)==3);
    request(&game,132); assert(fixtureDrawable[3]==1); request(&game,134); assert(fixtureTexture[3]==1);
    request(&game,180); request(&game,132); assert(fixtureDrawable[3]==2); request(&game,181); assert(fixtureDrawable[3]==1 && fixtureTexture[3]==1);
    fixtureModel=999; request(&game,181); assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE); fixtureModel=0x1234;
    request(&game,168); assert(fixtureDrawable[12]==0); request(&game,169); assert(fixtureDrawable[12]==-1);
    fixtureValid=false; request(&game,132); assert(PGTrainerStatus()==PG_TRAINER_UNAVAILABLE); fixtureValid=true;
    configuredStartMode=1; request(&game,132); assert(PGTrainerStatus()==PG_TRAINER_HANDLED); // Story clothes allowed, Story skins blocked
    char checkpointDirectory[]="/tmp/pg-sandbox-engine.XXXXXX";
    assert(mkdtemp(checkpointDirectory));
    pg_sandbox_store_configure(checkpointDirectory);
    PGSandboxCheckpoint checkpoint={750,-1250,45,90,1000};
    assert(pg_sandbox_store_write(&checkpoint));
    sandboxResumeChecked=false; configuredStartMode=2; fixtureCollision=false;
    pg_trainer_tick(&game);
    assert(sandboxResumePending && fixtureFrozen && fixturePosition.x==750);
    assert(!PGSandboxSaveAvailable() && !PGSandboxSaveRequest());
    now+=1; pg_trainer_tick(&game); assert(fixtureFrozen);
    fixtureCollision=true; pg_trainer_tick(&game); assert(!fixtureFrozen && !sandboxResumePending);
    pg_trainer_tick(&game); assert(PGSandboxSaveAvailable());
    fixturePosition.x=900;
    assert(PGSandboxSaveRequest());assert(!PGSandboxSaveRequest());pg_trainer_tick(&game);
    for(int i=0;i<1000 && PGSandboxSaveStatus()==1;i++)usleep(1000);
    assert(PGSandboxSaveStatus()==2);
    assert(pg_sandbox_store_load(&checkpoint) && checkpoint.x==900);
    sandboxResumeChecked=false; fixturePosition.x=123; fixtureCollision=false;
    pg_trainer_tick(&game); assert(fixturePosition.x==900 && fixtureFrozen);
    now+=21; pg_trainer_tick(&game); assert(fixturePosition.x==123 && !fixtureFrozen);
    char checkpointFile[1024];
    snprintf(checkpointFile,sizeof checkpointFile,"%s/sandbox-checkpoint.bin",checkpointDirectory);unlink(checkpointFile);
    snprintf(checkpointFile,sizeof checkpointFile,"%s/sandbox-checkpoint.bin.1",checkpointDirectory);unlink(checkpointFile);
    snprintf(checkpointFile,sizeof checkpointFile,"%s/sandbox-checkpoint.bin.2",checkpointDirectory);unlink(checkpointFile);
    rmdir(checkpointDirectory);
    puts("SANDBOX ENGINE CHECKS PASSED: save handoff, persisted location, collision-gated resume, duplicate requests and timeout rollback.");
    puts("WARDROBE CHECKS PASSED: bounded variants, prop removal, saved-look model guard, asynchronous loading, timeouts and Story protection.");
    free(env.memory.data);
    puts("TRAINER DISPATCH CHECKS PASSED: 85 routes, frame powers, exclusive ammo, named weather, stack lifetime, flight controls and cleanup.");
}
