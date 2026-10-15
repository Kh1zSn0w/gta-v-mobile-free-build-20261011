#include "NativeSandboxSave.h"
#include <pthread.h>

void w2c_game_f50028(w2c_game *, u64, u32, u32);
void w2c_game_f50133(w2c_game *, u32, u64, u32, u32, u32);
void w2c_game_f50135(w2c_game *, u32, float);
void w2c_game_f50102(w2c_game *, u32, u32);
u32 w2c_game_f50141(w2c_game *, u32);
void w2c_game_f60328(w2c_game *, u64);

static _Atomic bool sandboxSaveReady, sandboxSaveRequested;
static _Atomic uint32_t sandboxSaveStatus;
static bool sandboxResumeChecked, sandboxResumePending;
static uint32_t sandboxResumeHandle;
static uint64_t sandboxResumePed;
static double sandboxResumeDeadline;
static PGSandboxCheckpoint sandboxResume, sandboxOrigin;

bool PGSandboxSaveAvailable(void) { return atomic_load(&sandboxSaveReady); }
bool PGSandboxSaveRequest(void) {
    if (!PGSandboxSaveAvailable()) return false;
    uint32_t status=atomic_load(&sandboxSaveStatus);
    do { if (status==1) return false; }
    while (!atomic_compare_exchange_weak(&sandboxSaveStatus,&status,1));
    atomic_store(&sandboxSaveRequested,true);
    return true;
}
uint32_t PGSandboxSaveStatus(void) { return atomic_load(&sandboxSaveStatus); }

static bool pg_sandbox_capture(w2c_game *instance,uint32_t handle,PGSandboxCheckpoint *checkpoint) {
    uint64_t at=pg_trainer_scratch(instance);
    if (!handle || !at) return false;
    uint64_t saved=instance->w2c_g0;
    instance->w2c_g0=at;
    w2c_game_f50028(instance,at,handle,1);
    uint8_t *memory=(uint8_t *)(void *)env.memory.data;
    memcpy(&checkpoint->x,memory+at,4);
    memcpy(&checkpoint->y,memory+at+8,4);
    memcpy(&checkpoint->z,memory+at+16,4);
    instance->w2c_g0=saved;
    float heading=w2c_game_f50032(instance,handle);
    checkpoint->heading=isfinite(heading)?fmodf(fmodf(heading,360)+360,360):heading;
    checkpoint->savedAt=(uint64_t)time(NULL);
    return pg_sandbox_checkpoint_valid(checkpoint);
}

static void pg_sandbox_place(w2c_game *instance,uint32_t handle,const PGSandboxCheckpoint *checkpoint,bool move) {
    uint64_t at=pg_trainer_scratch(instance),saved=instance->w2c_g0;
    uint8_t *memory=(uint8_t *)(void *)env.memory.data;
    memset(memory+at,0,24);
    memcpy(memory+at,&checkpoint->x,4);
    memcpy(memory+at+8,&checkpoint->y,4);
    memcpy(memory+at+16,&checkpoint->z,4);
    instance->w2c_g0=at;
    w2c_game_f60328(instance,at);
    if (move) {
        w2c_game_f50133(instance,handle,at,0,0,1);
        w2c_game_f50135(instance,handle,checkpoint->heading);
    }
    instance->w2c_g0=saved;
}

static void *pg_sandbox_write_worker(void *pointer) {
    PGSandboxCheckpoint *checkpoint=pointer;
    bool written=pg_sandbox_store_write(checkpoint);
    free(checkpoint);
    atomic_store(&sandboxSaveStatus,written?2:4);
    pg_log(written?"Sandbox checkpoint saved with recovery backups.":"Sandbox checkpoint could not be written; previous checkpoint retained.");
    return NULL;
}

static bool pg_sandbox_tick(w2c_game *instance,bool ready,uint64_t ped,double now) {
    bool available=ready && configuredStartMode==2 && !wardrobePendingModel && !sandboxResumePending;
    atomic_store(&sandboxSaveReady,available);
    if (atomic_exchange(&sandboxSaveRequested,false)) {
        PGSandboxCheckpoint *checkpoint=available?malloc(sizeof *checkpoint):NULL;
        if (!available) atomic_store(&sandboxSaveStatus,3);
        else if (!checkpoint || !pg_sandbox_capture(instance,w2c_game_f58715(instance),checkpoint)) {
            free(checkpoint); atomic_store(&sandboxSaveStatus,4);
        } else {
            pthread_t thread;
            if (pthread_create(&thread,NULL,pg_sandbox_write_worker,checkpoint)) {
                free(checkpoint); atomic_store(&sandboxSaveStatus,4);
            } else pthread_detach(thread);
        }
    }
    if (configuredStartMode!=2) return false;
    if (sandboxResumePending) {
        // A replacement character must never inherit a freeze or a stale handle.
        if (ped!=sandboxResumePed) { sandboxResumePending=false; return false; }
        if (!ready) return true;
        if (!pg_trainer_scratch(instance)) return true;
        pg_sandbox_place(instance,sandboxResumeHandle,&sandboxResume,false);
        if (w2c_game_f50141(instance,sandboxResumeHandle)) {
            w2c_game_f50102(instance,sandboxResumeHandle,0);
            sandboxResumePending=false;
            pg_log("Sandbox checkpoint restored.");
        } else if (now>sandboxResumeDeadline) {
            pg_sandbox_place(instance,sandboxResumeHandle,&sandboxOrigin,true);
            w2c_game_f50102(instance,sandboxResumeHandle,0);
            sandboxResumePending=false;
            pg_log("Sandbox destination collision did not load; returned to the original spawn.");
        }
        return true;
    }
    if (sandboxResumeChecked || !available || pg_touch_context((const uint8_t *)(void *)env.memory.data,env.memory.size)!=0) return false;
    sandboxResumeChecked=true;
    if (!pg_sandbox_store_load(&sandboxResume)) return false;
    uint32_t handle=w2c_game_f58715(instance);
    if (!pg_sandbox_capture(instance,handle,&sandboxOrigin)) return false;
    // Match the engine teleport's actual accepted world bounds.
    if (fabsf(sandboxResume.x)>=16000 || fabsf(sandboxResume.y)>=16000 || sandboxResume.z<=-1700 || sandboxResume.z>=2700) return false;
    w2c_game_f50102(instance,handle,1);
    pg_sandbox_place(instance,handle,&sandboxResume,true);
    sandboxResumePending=true;
    sandboxResumeHandle=handle; sandboxResumePed=ped; sandboxResumeDeadline=now+20;
    atomic_store(&sandboxSaveReady,false);
    pg_log("Restoring Sandbox checkpoint; waiting for destination collision.");
    return true;
}
