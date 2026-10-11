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

static PGTrainerQueue trainerQueue;
static _Atomic bool trainerInvincible;
bool PGTrainerReady(void) { return atomic_load(&trainerQueue.ready); }
bool PGTrainerRequest(uint32_t command) {
    return pg_trainer_submit(&trainerQueue, command, timeMS(CLOCK_MONOTONIC) / 1000.0);
}
uint32_t PGTrainerStatus(void) { return atomic_load(&trainerQueue.status); }
bool PGTrainerInvincible(void) { return atomic_load(&trainerInvincible); }

void pg_trainer_tick(w2c_game *instance) {
    uint8_t *memory = (uint8_t *)(void *)env.memory.data;
    uint64_t size = env.memory.size, info = 0, ped = 0, frontend = 0, world = 0;
    bool ready = memory && size >= 28501282 &&
        pg_context_u64(memory, size, 20159720, &info) && info && info <= size - 16 &&
        pg_context_u64(memory, size, info + 8, &ped) && ped && ped <= size && size - ped >= 5584 &&
        pg_context_u64(memory, size, 19603008, &frontend) && frontend && frontend < size &&
        pg_context_u64(memory, size, 26005240, &world) && world && world < size &&
        !memory[28501281] && !(memory[18581341] & 1) && !PGPauseMenuActive();
    float health = 0;
    if (ready) memcpy(&health, memory + ped + 672, sizeof health);
    ready = ready && isfinite(health) && health > 0;
    if (memory && size > 20156137) atomic_store(&trainerInvincible, memory[20156137] != 0);
    uint32_t command = pg_trainer_take(&trainerQueue, ready, timeMS(CLOCK_MONOTONIC) / 1000.0);
    if (!command) return;
    switch (command) {
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
    }
    pg_trainer_finish(&trainerQueue);
    char line[96];
    snprintf(line, sizeof line, "Trainer command %u handled on the engine cheat-update thread.", command);
    pg_log(line);
}
