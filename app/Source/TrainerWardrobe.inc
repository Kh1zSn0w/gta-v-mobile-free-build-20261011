// Clothing and skin changes are engine-thread-only. UIKit sees atomic snapshots.
void w2c_game_f58625(w2c_game* instance, u32 var_p0, u32 var_p1);
void w2c_game_f60322(w2c_game* instance, u32 var_p0);
u32 w2c_game_f60324(w2c_game* instance, u32 var_p0);
void w2c_game_f60327(w2c_game* instance, u32 var_p0);
u32 w2c_game_f60347(w2c_game* instance, u32 var_p0);
u32 w2c_game_f60348(w2c_game* instance, u32 var_p0);
u32 w2c_game_f50040(w2c_game* instance, u32 var_p0);
u32 w2c_game_f57381(w2c_game* instance, u32 var_p0, u32 var_p1);
u32 w2c_game_f57382(w2c_game* instance, u32 var_p0, u32 var_p1);
u32 w2c_game_f57383(w2c_game* instance, u32 var_p0, u32 var_p1);
u32 w2c_game_f57384(w2c_game* instance, u32 var_p0, u32 var_p1);
u32 w2c_game_f57385(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2);
u32 w2c_game_f57386(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2);
u32 w2c_game_f57391(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3);
void w2c_game_f57392(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3, u32 var_p4);
void w2c_game_f57393(w2c_game* instance, u32 var_p0, u32 var_p1);
void w2c_game_f57394(w2c_game* instance, u32 var_p0);
void w2c_game_f57395(w2c_game* instance, u32 var_p0);
u32 w2c_game_f57435(w2c_game* instance, u32 var_p0, u32 var_p1);
void w2c_game_f57436(w2c_game* instance, u32 var_p0, u32 var_p1, u32 var_p2, u32 var_p3, u32 var_p4);
u32 w2c_game_f57438(w2c_game* instance, u32 var_p0, u32 var_p1);
void w2c_game_f57439(w2c_game* instance, u32 var_p0, u32 var_p1);
void w2c_game_f57440(w2c_game* instance, u32 var_p0);

static const char *const wardrobePolice[] = {"police2", "police3", "police4", "policeb", "policet", "sheriff", "sheriff2", "fbi2", "pranger", "riot", "pbus", "polmav", "policeold1", "policeold2", "crusader"};
static const char *const wardrobeModels[] = {"s_m_y_cop_01", "s_f_y_cop_01", "s_m_y_swat_01", "s_m_y_sheriff_01", "s_f_y_sheriff_01", "s_m_y_hwaycop_01", "s_m_m_fiboffice_01", "s_m_m_fiboffice_02", "s_m_m_fibsec_01", "s_m_m_highsec_01", "s_m_m_highsec_02", "ig_bankman", "ig_fbisuit_01", "u_m_m_jewelsec_01"};
static _Atomic bool wardrobeSkinReady, wardrobeSavedReady;
static _Atomic uint32_t wardrobeSlot;
static _Atomic uint64_t wardrobeStates[15];
static double wardrobeNextRefresh;
static _Atomic uint32_t wardrobeOriginalModel;
static uint32_t wardrobePendingModel;
static uint64_t wardrobePendingPed;
static double wardrobeDeadline;
static bool wardrobeSwapped;
static _Thread_local bool wardrobePreloadedSwap;
static uint32_t wardrobeReleaseModel;

bool pg_wardrobe_preloaded_swap(void) { return wardrobePreloadedSwap; }
typedef struct { int32_t drawable, texture; } PGWardrobePiece;
static PGWardrobePiece wardrobeSaved[15];
static uint32_t wardrobeSavedModel;

bool PGTrainerCommandAvailable(uint32_t command) {
    if (!PGTrainerReady() || !pg_trainer_valid(command)) return false;
    if (command >= 101 && command <= 115)
        return atomic_load(&wardrobeSkinReady) && (command != 115 || wardrobeOriginalModel != 0);
    if (command == PG_TRAINER_APPLY_LOOK) return atomic_load(&wardrobeSavedReady);
    return true;
}
void PGTrainerSelectClothingSlot(uint32_t slot) { if (slot < 15) atomic_store(&wardrobeSlot, slot); }
uint64_t PGTrainerClothingState(uint32_t slot) { return slot < 15 ? atomic_load(&wardrobeStates[slot]) : 0; }
static uint32_t pg_wardrobe_hash(const char *name) {
    uint32_t hash = 0;
    for (; *name; name++) { hash += (uint8_t)*name; hash += hash << 10; hash ^= hash >> 6; }
    hash += hash << 3; hash ^= hash >> 11; hash += hash << 15;
    return hash;
}
static int32_t pg_wardrobe_drawable(w2c_game *instance, uint32_t ped, uint32_t slot) {
    return (int32_t)(slot < 12 ? w2c_game_f57381(instance,ped,slot) : w2c_game_f57435(instance,ped,slot-12));
}
static uint32_t pg_wardrobe_count(w2c_game *instance, uint32_t ped, uint32_t slot) {
    return slot < 12 ? w2c_game_f57383(instance,ped,slot) : w2c_game_f57382(instance,ped,slot-12);
}
static uint32_t pg_wardrobe_texture_count(w2c_game *instance,uint32_t ped,uint32_t slot,int32_t drawable) {
    if (drawable < 0) return 0;
    return slot < 12 ? w2c_game_f57385(instance,ped,slot,(u32)drawable) : w2c_game_f57386(instance,ped,slot-12,(u32)drawable);
}
static int32_t pg_wardrobe_texture(w2c_game *instance,uint32_t ped,uint32_t slot) {
    return (int32_t)(slot < 12 ? w2c_game_f57384(instance,ped,slot) : w2c_game_f57438(instance,ped,slot-12));
}
static bool pg_wardrobe_set(w2c_game *instance,uint32_t ped,uint32_t slot,int32_t drawable,int32_t texture) {
    if (slot >= 12 && drawable == -1) { w2c_game_f57439(instance,ped,slot-12); return true; }
    uint32_t count = pg_wardrobe_count(instance,ped,slot);
    uint32_t textures = pg_wardrobe_texture_count(instance,ped,slot,drawable);
    if (drawable < 0 || count > 1024 || (uint32_t)drawable >= count || texture < 0 || !textures || textures > 1024 || (uint32_t)texture >= textures) return false;
    if (slot < 12) {
        if (!w2c_game_f57391(instance,ped,slot,(u32)drawable,(u32)texture)) return false;
        w2c_game_f57392(instance,ped,slot,(u32)drawable,(u32)texture,0);
    } else w2c_game_f57436(instance,ped,slot-12,(u32)drawable,(u32)texture,1);
    wardrobeNextRefresh = 0;
    return true;
}
static bool pg_wardrobe_cycle(w2c_game *instance,uint32_t command) {
    uint32_t slot, action;
    if (command <= 167) { slot=(command-120)/4; action=(command-120)%4; }
    else { slot=12+(command-168)/4; action=(command-168)%4; }
    uint32_t ped=w2c_game_f58715(instance),count=pg_wardrobe_count(instance,ped,slot);
    if (!ped || !count || count>1024) return false;
    int32_t drawable=pg_wardrobe_drawable(instance,ped,slot),texture=pg_wardrobe_texture(instance,ped,slot);
    if (action<2) {
        int32_t first=slot<12?0:-1, last=(int32_t)count-1;
        drawable += action==0?1:-1;
        if (drawable>last) drawable=first;
        if (drawable<first) drawable=last;
        texture=0;
    } else {
        uint32_t textures=pg_wardrobe_texture_count(instance,ped,slot,drawable);
        if (drawable<0 || textures<2 || textures>1024) return false;
        texture=(texture+(action==2?1:(int32_t)textures-1))%(int32_t)textures;
    }
    return pg_wardrobe_set(instance,ped,slot,drawable,texture);
}
static void pg_wardrobe_refresh(w2c_game *instance,bool ready,uint64_t ped,double now) {
    // CHANGE_PLAYER_MODEL asserts that the ped has a live script task. Match
    // that prerequisite rather than calling the native from an incomplete scene.
    uint64_t intelligence=0,script=0; uint32_t scriptCount=0;
    const uint8_t *memory=(const uint8_t *)(void *)env.memory.data;
    bool skin=ready && configuredStartMode==2 && pg_touch_context(memory,env.memory.size)==0 &&
        pg_context_u64(memory,env.memory.size,ped+4320,&intelligence) && intelligence &&
        pg_context_u32(memory,env.memory.size,intelligence+4064,&scriptCount) && scriptCount &&
        pg_context_u64(memory,env.memory.size,intelligence+4032,&script) && script && script<env.memory.size;
    atomic_store(&wardrobeSkinReady,skin);
    if (!ready) { for (unsigned i=0;i<15;i++) atomic_store(&wardrobeStates[i],0); return; }
    uint32_t handle=w2c_game_f58715(instance);
    atomic_store(&wardrobeSavedReady,wardrobeSavedModel && w2c_game_f50040(instance,handle)==wardrobeSavedModel);
    if (now<wardrobeNextRefresh) return;
    wardrobeNextRefresh=now+.15;
    uint32_t slot=atomic_load(&wardrobeSlot),count=pg_wardrobe_count(instance,handle,slot);
    int32_t drawable=pg_wardrobe_drawable(instance,handle,slot),texture=pg_wardrobe_texture(instance,handle,slot);
    uint32_t textures=pg_wardrobe_texture_count(instance,handle,slot,drawable);
    uint64_t state=0;
    if (count && count<=1024 && textures<=1024 && drawable>=-1 && drawable<(int32_t)count && texture>=-1 && texture<1024)
        state=(uint64_t)(drawable+1)|((uint64_t)count<<16)|((uint64_t)(texture<0?0:texture)<<32)|((uint64_t)textures<<48);
    atomic_store(&wardrobeStates[slot],state);
}
static bool pg_wardrobe_begin_skin(w2c_game *instance,uint32_t command,uint64_t ped,double now) {
    if (!atomic_load(&wardrobeSkinReady)) return false;
    uint32_t hash=command==115?wardrobeOriginalModel:pg_wardrobe_hash(wardrobeModels[command-101]);
    if (!hash || !w2c_game_f60347(instance,hash) || !w2c_game_f60348(instance,hash)) return false;
    if (!wardrobeOriginalModel) wardrobeOriginalModel=w2c_game_f50040(instance,w2c_game_f58715(instance));
    wardrobePendingModel=hash; wardrobePendingPed=ped; wardrobeDeadline=now+15; wardrobeSwapped=false;
    w2c_game_f60322(instance,hash);
    return true;
}
static bool pg_wardrobe_loading(w2c_game *instance,bool ready,uint64_t ped,double now) {
    if (ready && wardrobeReleaseModel) {
        w2c_game_f60327(instance,wardrobeReleaseModel);
        wardrobeReleaseModel=0;
    }
    if (!wardrobePendingModel) return false;
    uint32_t result=PG_TRAINER_PENDING;
    if (now>wardrobeDeadline || (!wardrobeSwapped && (ped!=wardrobePendingPed || !atomic_load(&wardrobeSkinReady)))) result=PG_TRAINER_EXPIRED;
    else if (!ready) return true;
    else if (!wardrobeSwapped && w2c_game_f60324(instance,wardrobePendingModel)) {
        pg_trainer_reset(instance,w2c_game_f58714(instance));
        // The requested model is resident. A synchronous streaming flush here
        // can wait on the scheduler callback currently executing this request.
        wardrobePreloadedSwap=true;
        w2c_game_f58625(instance,w2c_game_f58714(instance),wardrobePendingModel);
        wardrobePreloadedSwap=false;
        wardrobeSwapped=true;
        return true; // Resolve the new ped handle next update; never use the old one.
    } else if (wardrobeSwapped && w2c_game_f50040(instance,w2c_game_f58715(instance))==wardrobePendingModel) result=PG_TRAINER_HANDLED;
    if (result!=PG_TRAINER_PENDING) {
        if (ready) w2c_game_f60327(instance,wardrobePendingModel);
        else wardrobeReleaseModel=wardrobePendingModel;
        if (result==PG_TRAINER_HANDLED && atomic_load(&trainerQueue.command)==115) wardrobeOriginalModel=0;
        wardrobePendingModel=0; wardrobeNextRefresh=0;
        atomic_store(&trainerQueue.status,result); atomic_store(&trainerQueue.command,0);
    }
    return true;
}
static bool pg_wardrobe_command(w2c_game *instance,uint32_t command) {
    if (command>=86 && command<=100) return pg_trainer_named(instance,wardrobePolice[command-86],true);
    uint32_t ped=w2c_game_f58715(instance);
    if (!ped) return false;
    if (command>=120 && command<=179) return pg_wardrobe_cycle(instance,command);
    switch(command) {
        case 116: w2c_game_f57395(instance,ped); break;
        case 117: w2c_game_f57393(instance,ped,0); break;
        case 118: w2c_game_f57394(instance,ped); break;
        case 119: w2c_game_f57440(instance,ped); break;
        case 180:
            wardrobeSavedModel=w2c_game_f50040(instance,ped);
            for(uint32_t slot=0;slot<15;slot++) wardrobeSaved[slot]=(PGWardrobePiece){pg_wardrobe_drawable(instance,ped,slot),pg_wardrobe_texture(instance,ped,slot)};
            break;
        case 181:
            if (!wardrobeSavedModel || wardrobeSavedModel!=w2c_game_f50040(instance,ped)) return false;
            for(uint32_t slot=0;slot<15;slot++) {
                PGWardrobePiece piece=wardrobeSaved[slot];
                if (pg_wardrobe_count(instance,ped,slot) && !pg_wardrobe_set(instance,ped,slot,piece.drawable,piece.texture)) return false;
            }
            break;
        default: return false;
    }
    wardrobeNextRefresh=0;
    return true;
}
