#include "NativeTrainer.h"
#include "NativeTouchContext.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <time.h>
typedef uint32_t u32;
typedef struct { int unused; } w2c_game;
static struct { struct { uint8_t *data; uint64_t size; } memory; } env;
static double now;
static bool paused;
static double timeMS(int clock) { (void)clock; return now * 1000; }
static bool PGPauseMenuActive(void) { return paused; }
static void pg_log(const char *message) { (void)message; }
#include "TrainerEngine.inc"
static int called, count;
static u32 hour, minute, second;
#define CHEAT(number) void w2c_game_f##number(w2c_game *game) { (void)game; called=number; count++; }
CHEAT(37634) CHEAT(37635) CHEAT(37636) CHEAT(37638) CHEAT(37639)
CHEAT(37641) CHEAT(37644) CHEAT(37645) CHEAT(37646) CHEAT(37650)
void w2c_game_f49437(w2c_game *game, u32 h, u32 m, u32 s) {
    (void)game; called=49437; count++; hour=h; minute=m; second=s;
}
static void pointer(uint64_t address, uint64_t value) { memcpy(env.memory.data+address, &value, 8); }
int main(void) {
    w2c_game game = {0};
    pg_trainer_tick(&game);
    assert(!PGTrainerReady());
    env.memory.size=32*1024*1024;
    env.memory.data=calloc(1,env.memory.size);
    assert(env.memory.data);
    pointer(20159720,30000000);
    pointer(30000008,30001000);
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
    for(int guard=0;guard<3;guard++) {
        if(guard==0) env.memory.data[28501281]=1;
        if(guard==1) env.memory.data[18581341]=1;
        if(guard==2) {health=0;memcpy(env.memory.data+30001000+672,&health,4);}
        pg_trainer_tick(&game); assert(!PGTrainerReady());
        assert(!PGTrainerRequest(1));
        env.memory.data[28501281]=env.memory.data[18581341]=0;
    }
    free(env.memory.data);
    puts("TRAINER DISPATCH CHECKS PASSED: exact 15 native routes, invincibility, clock, menu/death/network guards.");
}
