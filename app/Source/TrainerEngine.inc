// These pinned functions already implement model streaming, placement, loadouts,
// health restoration and wanted-level changes. No game object is modified by UIKit.
void w2c_game_f37634(w2c_game *);
void w2c_game_f37635(w2c_game *);
void w2c_game_f37636(w2c_game *);
void w2c_game_f37638(w2c_game *);
void w2c_game_f37639(w2c_game *);
void w2c_game_f37641(w2c_game *);
void w2c_game_f37644(w2c_game *);
void w2c_game_f37645(w2c_game *);
void w2c_game_f37646(w2c_game *);
void w2c_game_f37650(w2c_game *);
void w2c_game_f49437(w2c_game *, u32, u32, u32);

// Signatures checked against this exact release during engine preparation.
void w2c_game_f37642(w2c_game *, u64, u32);
void w2c_game_f52794(w2c_game *, u64);
void w2c_game_f52797(w2c_game *);
void w2c_game_f52798(w2c_game *);
u32 w2c_game_f37934(w2c_game *, u64);
void w2c_game_f53007(w2c_game *, u32);
void w2c_game_f53008(w2c_game *, u32);
void w2c_game_f53009(w2c_game *, u32);
void w2c_game_f53010(w2c_game *, u32);
u32 w2c_game_f58714(w2c_game *);
u32 w2c_game_f58715(w2c_game *);
void w2c_game_f58753(w2c_game *, u32, float);
void w2c_game_f58754(w2c_game *, u32, float);
void w2c_game_f58646(w2c_game *, u32);
void w2c_game_f58699(w2c_game *, u32);
void w2c_game_f58779(w2c_game *, u32, u32, u32);
u32 w2c_game_f57184(w2c_game *, u32, u32);
void w2c_game_f61578(w2c_game *, u32);
void w2c_game_f50154(w2c_game *, u32, u64);
void w2c_game_f50156(w2c_game *, u32, u32);
float w2c_game_f50032(w2c_game *, u32);
void w2c_game_f52941(w2c_game *, u32);

static const char *const trainerVehicles[] = {"adder","zentorno","t20","osiris","entityxf","infernus","vacca","voltic","cheetah","bullet","banshee","buffalo","elegy2","jester","massacro","sultan","futo","sentinel","dominator","gauntlet","dukes","sandking","rebel","bifta","blazer","bati","akuma","hakuchou","vader","bmx","police","ambulance","firetruk","rhino","buzzard","frogger","lazer","duster","stunt","dinghy"};
static const char *const trainerWeather[] = {"EXTRASUNNY","CLEAR","CLOUDS","OVERCAST","RAIN","THUNDER","FOGGY","SMOG","CLEARING","SNOW","BLIZZARD","XMAS"};

static PGTrainerQueue trainerQueue;
static _Atomic bool trainerInvincible;
static _Atomic uint32_t trainerToggles;
static uint64_t trainerPed;
static uint32_t flyingPed;
static bool trainerResetPending, trainerMoonResetPending;
bool PGTrainerToggleState(uint32_t command) {
    return (atomic_load(&trainerToggles) & pg_trainer_toggle_bit(command)) != 0;
}
// Reserve temporary arguments on the calling engine thread's own WASM stack.
// VehicleCheat hashes its string before spawning; no borrowed host pointer escapes.
static uint64_t pg_trainer_scratch(w2c_game *instance) {
    uint64_t top = instance->w2c_g0;
    return top >= 16384 && top <= env.memory.size && !(top & 15) ? top - 128 : 0;
}
static bool pg_trainer_named(w2c_game *instance, const char *name, bool vehicle) {
    uint64_t at = pg_trainer_scratch(instance);
    size_t length = strlen(name) + 1;
    if (!at || length > 128) return false;
    memcpy((uint8_t *)(void *)env.memory.data + at, name, length);
    uint64_t saved = instance->w2c_g0;
    instance->w2c_g0 = at;
    bool valid = true;
    if (vehicle) w2c_game_f37642(instance, at, 1);
    else {
        int32_t index = (int32_t)w2c_game_f37934(instance, at);
        uint32_t count = 0;
        valid = index >= 0 && pg_context_u32((const uint8_t *)(void *)env.memory.data,
                    env.memory.size, 19611536, &count) && (uint32_t)index < count;
        if (valid) w2c_game_f52794(instance, at);
    }
    instance->w2c_g0 = saved;
    return valid;
}
static void pg_trainer_velocity(w2c_game *instance, uint32_t handle, float x, float y, float z) {
    uint64_t at = pg_trainer_scratch(instance);
    if (!at || !handle || !isfinite(x) || !isfinite(y) || !isfinite(z)) return;
    // rage::scrVector stores its float components in eight-byte slots.
    uint8_t *memory = (uint8_t *)(void *)env.memory.data;
    memset(memory + at, 0, 24);
    memcpy(memory + at, &x, 4); memcpy(memory + at + 8, &y, 4); memcpy(memory + at + 16, &z, 4);
    uint64_t saved = instance->w2c_g0;
    instance->w2c_g0 = at;
    w2c_game_f50154(instance, handle, at);
    instance->w2c_g0 = saved;
}
static void pg_trainer_stop_flight(w2c_game *instance) {
    if (flyingPed) w2c_game_f50156(instance, flyingPed, 1);
    flyingPed = 0;
}
static void pg_trainer_reset(w2c_game *instance, uint32_t player) {
    pg_trainer_stop_flight(instance);
    w2c_game_f58754(instance, player, 1.0f);
    w2c_game_f58753(instance, player, 1.0f);
    if (PGTrainerToggleState(PG_TRAINER_MOON_GRAVITY) || trainerMoonResetPending) w2c_game_f52941(instance, 0);
    trainerResetPending = trainerMoonResetPending = false;
    atomic_store(&trainerToggles, 0);
}
static void pg_trainer_powers(w2c_game *instance, uint32_t player, bool onFoot) {
    uint32_t toggles = atomic_load(&trainerToggles);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_SUPER_JUMP)) w2c_game_f53010(instance, player);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_EXPLOSIVE_MELEE)) w2c_game_f53009(instance, player);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_EXPLOSIVE_AMMO)) w2c_game_f53007(instance, player);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_FIRE_AMMO)) w2c_game_f53008(instance, player);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_STAMINA)) w2c_game_f58699(instance, player);
    if (toggles & pg_trainer_toggle_bit(PG_TRAINER_NO_WANTED)) w2c_game_f58646(instance, player);
    if (!(toggles & pg_trainer_toggle_bit(PG_TRAINER_FLIGHT)) || !onFoot) {
        pg_trainer_stop_flight(instance);
        return;
    }
    uint32_t handle = w2c_game_f58715(instance);
    if (!handle || !pg_trainer_scratch(instance)) { pg_trainer_stop_flight(instance); return; }
    if (flyingPed != handle) { pg_trainer_stop_flight(instance); flyingPed = handle; }
    w2c_game_f50156(instance, handle, 0);
    uint64_t pad = atomic_load(&virtualPad);
    float x = ((int)((pad >> 16) & 255) - 127.5f) / 127.5f;
    float y = (127.5f - (int)((pad >> 24) & 255)) / 127.5f;
    if (fabsf(x) < .08f) x = 0;
    if (fabsf(y) < .08f) y = 0;
    float length = sqrtf(x*x + y*y);
    if (length > 1) { x /= length; y /= length; }
    float heading = w2c_game_f50032(instance, handle) * (3.14159265359f / 180.0f);
    float speed = (pad & 64) ? 22.0f : 12.0f;
    float z = ((pad & 128) ? 8.0f : 0) - ((pad & 512) ? 8.0f : 0);
    pg_trainer_velocity(instance, handle, (cosf(heading)*x - sinf(heading)*y)*speed,
                        (sinf(heading)*x + cosf(heading)*y)*speed, z);
}
bool PGTrainerReady(void) { return atomic_load(&trainerQueue.ready); }
bool PGTrainerRequest(uint32_t command) {
    return pg_trainer_submit(&trainerQueue, command, timeMS(CLOCK_MONOTONIC) / 1000.0);
}
uint32_t PGTrainerStatus(void) { return atomic_load(&trainerQueue.status); }
bool PGTrainerInvincible(void) { return atomic_load(&trainerInvincible); }

void pg_trainer_tick(w2c_game *instance) {
    uint8_t *memory = (uint8_t *)(void *)env.memory.data;
    uint64_t size = env.memory.size, info = 0, ped = 0, playerState = 0, frontend = 0, world = 0;
    bool ready = memory && size >= 28501282 &&
        pg_context_u64(memory, size, 20159720, &info) && info && info <= size - 16 &&
        pg_context_u64(memory, size, info + 8, &ped) && ped && ped <= size && size - ped >= 5584 &&
        pg_context_u64(memory, size, 19603008, &frontend) && frontend && frontend < size &&
        pg_context_u64(memory, size, 26005240, &world) && world && world < size &&
        pg_context_u64(memory, size, ped + 4328, &playerState) && playerState && playerState <= size && size - playerState >= 3900 &&
        !memory[28501281] && !(memory[18581341] & 1) && !PGPauseMenuActive();
    bool validContext = ready;
    float health = 0;
    if (memory && ped && ped <= size && size - ped >= 676) memcpy(&health, memory + ped + 672, sizeof health);
    ready = ready && isfinite(health) && health > 0;
    if (memory && size > 20156137) atomic_store(&trainerInvincible, memory[20156137] != 0);
    // Clear our active powers on death or player replacement. Flight suspends in vehicles.
    // Script handles are resolved by the engine, never retained as raw object pointers.
    bool offline = memory && size >= 28501282 && !memory[28501281];
    if (offline && trainerPed && (trainerPed != ped || !isfinite(health) || health <= 0)) {
        if (validContext) pg_trainer_reset(instance, 0);
        else {
            // World teardown has no safe native-call context. Defer restoration
            // until the next valid player instead of calling into unloaded pools.
            trainerMoonResetPending = trainerMoonResetPending || PGTrainerToggleState(PG_TRAINER_MOON_GRAVITY);
            trainerResetPending = true;
            atomic_store(&trainerToggles, 0);
        }
        trainerPed = 0;
    }
    if (ready && trainerResetPending) pg_trainer_reset(instance, 0);
    if (ready) trainerPed = ped;
    uint32_t command = pg_trainer_take(&trainerQueue, ready, timeMS(CLOCK_MONOTONIC) / 1000.0);
    uint32_t player = ready ? w2c_game_f58714(instance) : 0;
    bool handled = true;
    if (command >= PG_TRAINER_SUPER_JUMP && command <= PG_TRAINER_FLIGHT) {
        uint32_t flags = atomic_load(&trainerToggles) ^ pg_trainer_toggle_bit(command);
        // Bullet modes are exclusive so their damage behaviour stays predictable.
        if (command == PG_TRAINER_EXPLOSIVE_AMMO) flags &= ~pg_trainer_toggle_bit(PG_TRAINER_FIRE_AMMO);
        if (command == PG_TRAINER_FIRE_AMMO) flags &= ~pg_trainer_toggle_bit(PG_TRAINER_EXPLOSIVE_AMMO);
        atomic_store(&trainerToggles, flags);
        if (command == PG_TRAINER_FAST_RUN) w2c_game_f58754(instance, player, PGTrainerToggleState(command) ? 1.49f : 1.0f);
        if (command == PG_TRAINER_FAST_SWIM) w2c_game_f58753(instance, player, PGTrainerToggleState(command) ? 1.49f : 1.0f);
    } else if (command >= PG_TRAINER_NAMED_WEATHER_FIRST && command <= PG_TRAINER_NAMED_WEATHER_LAST) {
        handled = pg_trainer_named(instance, trainerWeather[command - PG_TRAINER_NAMED_WEATHER_FIRST], false);
    } else if (command >= PG_TRAINER_VEHICLE_FIRST && command <= PG_TRAINER_VEHICLE_LAST) {
        handled = pg_trainer_named(instance, trainerVehicles[command - PG_TRAINER_VEHICLE_FIRST], true);
    } else switch (command) {
        case PG_TRAINER_HEALTH: w2c_game_f37635(instance); break;
        case PG_TRAINER_WEAPONS: w2c_game_f37634(instance); break;
        case PG_TRAINER_WANTED_DOWN: w2c_game_f37638(instance); break;
        case PG_TRAINER_WANTED_UP: w2c_game_f37636(instance); break;
        case PG_TRAINER_INVINCIBLE:
            // The exact developer-toggle branch in DoCheats resets the alternate
            // damage mode and toggles this flag. The engine applies it to the player.
            memory[20156136] = 0;
            memory[20156137] = memory[20156137] ? 0 : 1;
            atomic_store(&trainerInvincible, memory[20156137] != 0);
            break;
        case PG_TRAINER_WEATHER: w2c_game_f37639(instance); break;
        case PG_TRAINER_COMET: w2c_game_f37646(instance); break;
        case PG_TRAINER_SANCHEZ: w2c_game_f37650(instance); break;
        case PG_TRAINER_FBI: w2c_game_f37644(instance); break;
        case PG_TRAINER_HELI: w2c_game_f37641(instance); break;
        case PG_TRAINER_BOAT: w2c_game_f37645(instance); break;
        case PG_TRAINER_DAWN: w2c_game_f49437(instance, 6, 0, 0); break;
        case PG_TRAINER_NOON: w2c_game_f49437(instance, 12, 0, 0); break;
        case PG_TRAINER_SUNSET: w2c_game_f49437(instance, 19, 0, 0); break;
        case PG_TRAINER_MIDNIGHT: w2c_game_f49437(instance, 0, 0, 0); break;
        case PG_TRAINER_RESET:
            pg_trainer_reset(instance, player);
            memory[20156137] = 0; atomic_store(&trainerInvincible, false);
            break;
        case PG_TRAINER_CLEAR_WANTED: w2c_game_f58646(instance, player); break;
        case PG_TRAINER_SPECIAL: w2c_game_f58779(instance, player, 0, 0); break;
        case PG_TRAINER_REPAIR: {
            uint32_t vehicle = w2c_game_f57184(instance, w2c_game_f58715(instance), 0);
            if (vehicle) w2c_game_f61578(instance, vehicle); else handled = false;
            break;
        }
        case PG_TRAINER_SKY_BOOST:
            if (pg_touch_context(memory, size) == 0) pg_trainer_velocity(instance, w2c_game_f58715(instance), 0, 0, 35);
            else handled = false;
            break;
        case PG_TRAINER_MOON_GRAVITY: {
            uint32_t flags = atomic_load(&trainerToggles) ^ pg_trainer_toggle_bit(command);
            atomic_store(&trainerToggles, flags);
            w2c_game_f52941(instance, PGTrainerToggleState(command) ? 1 : 0);
            break;
        }
        case PG_TRAINER_NORMAL_GRAVITY:
            atomic_fetch_and(&trainerToggles, ~pg_trainer_toggle_bit(PG_TRAINER_MOON_GRAVITY));
            w2c_game_f52941(instance, 0); break;
        case PG_TRAINER_RANDOM_WEATHER: w2c_game_f52797(instance); break;
        case PG_TRAINER_AUTO_WEATHER: w2c_game_f52798(instance); break;
    }
    if (ready) pg_trainer_powers(instance, player, pg_touch_context(memory, size) == 0);
    if (!command) return;
    if (handled) pg_trainer_finish(&trainerQueue);
    else {
        atomic_store(&trainerQueue.status, PG_TRAINER_UNAVAILABLE);
        atomic_store(&trainerQueue.command, 0);
        return;
    }
    char line[96];
    snprintf(line, sizeof line, "Trainer command %u handled on the engine cheat-update thread.", command);
    pg_log(line);
}
