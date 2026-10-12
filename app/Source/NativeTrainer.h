#pragma once
#include <stdbool.h>
#include <stdint.h>
#include <stdatomic.h>

// One outstanding request. UIKit never touches game objects or calls engine code.
enum { PG_TRAINER_IDLE, PG_TRAINER_PENDING, PG_TRAINER_HANDLED,
       PG_TRAINER_UNAVAILABLE, PG_TRAINER_EXPIRED };
enum { PG_TRAINER_HEALTH = 1, PG_TRAINER_WEAPONS, PG_TRAINER_WANTED_DOWN,
       PG_TRAINER_WANTED_UP, PG_TRAINER_INVINCIBLE, PG_TRAINER_WEATHER,
       PG_TRAINER_COMET, PG_TRAINER_SANCHEZ, PG_TRAINER_FBI,
       PG_TRAINER_HELI, PG_TRAINER_BOAT, PG_TRAINER_DAWN,
       PG_TRAINER_NOON, PG_TRAINER_SUNSET, PG_TRAINER_MIDNIGHT,
       PG_TRAINER_SUPER_JUMP, PG_TRAINER_EXPLOSIVE_MELEE, PG_TRAINER_EXPLOSIVE_AMMO,
       PG_TRAINER_FIRE_AMMO, PG_TRAINER_FAST_RUN, PG_TRAINER_FAST_SWIM,
       PG_TRAINER_STAMINA, PG_TRAINER_NO_WANTED, PG_TRAINER_FLIGHT,
       PG_TRAINER_RESET, PG_TRAINER_CLEAR_WANTED, PG_TRAINER_SPECIAL,
       PG_TRAINER_REPAIR, PG_TRAINER_SKY_BOOST, PG_TRAINER_MOON_GRAVITY,
       PG_TRAINER_NORMAL_GRAVITY, PG_TRAINER_RANDOM_WEATHER, PG_TRAINER_AUTO_WEATHER,
       PG_TRAINER_NAMED_WEATHER_FIRST = 34, PG_TRAINER_NAMED_WEATHER_LAST = 45,
       PG_TRAINER_VEHICLE_FIRST = 46, PG_TRAINER_VEHICLE_LAST = 85,
       PG_TRAINER_POLICE_FIRST = 86, PG_TRAINER_POLICE_LAST = 100,
       PG_TRAINER_SKIN_FIRST = 101, PG_TRAINER_SKIN_LAST = 114,
       PG_TRAINER_RESTORE_CHARACTER = 115, PG_TRAINER_DEFAULT_CLOTHES,
       PG_TRAINER_RANDOM_CLOTHES, PG_TRAINER_RANDOM_PROPS, PG_TRAINER_CLEAR_PROPS,
       PG_TRAINER_COMPONENT_FIRST = 120, PG_TRAINER_COMPONENT_LAST = 167,
       PG_TRAINER_PROP_FIRST = 168, PG_TRAINER_PROP_LAST = 179,
       PG_TRAINER_SAVE_LOOK = 180, PG_TRAINER_APPLY_LOOK = 181,
       PG_TRAINER_LAST = 181 };
static inline uint32_t pg_trainer_toggle_bit(uint32_t command) {
    return command >= 16 && command <= 24 ? 1u << (command - 16) :
           command == PG_TRAINER_MOON_GRAVITY ? 1u << 9 : 0;
}
typedef struct {
    _Atomic uint32_t command;
    _Atomic uint32_t status;
    _Atomic bool ready;
    double deadline; // Written before publishing command; read only after acquiring it.
} PGTrainerQueue;
static inline bool pg_trainer_valid(uint32_t command) {
    return command >= PG_TRAINER_HEALTH && command <= PG_TRAINER_LAST;
}
static inline bool pg_trainer_submit(PGTrainerQueue *queue, uint32_t command, double now) {
    if (!pg_trainer_valid(command) || !atomic_load(&queue->ready) || atomic_load(&queue->command)) return false;
    queue->deadline = now + 5;
    atomic_store(&queue->status, PG_TRAINER_PENDING);
    atomic_store_explicit(&queue->command, command, memory_order_release);
    return true;
}
static inline uint32_t pg_trainer_take(PGTrainerQueue *queue, bool ready, double now) {
    atomic_store(&queue->ready, ready);
    uint32_t command = atomic_load_explicit(&queue->command, memory_order_acquire);
    if (!command) return 0;
    if (!ready || now > queue->deadline) {
        atomic_store(&queue->status, ready ? PG_TRAINER_EXPIRED : PG_TRAINER_UNAVAILABLE);
        atomic_store(&queue->command, 0);
        return 0;
    }
    // Remains occupied until the engine call finishes, preventing another publisher.
    return command;
}
static inline void pg_trainer_finish(PGTrainerQueue *queue) {
    atomic_store(&queue->status, PG_TRAINER_HANDLED);
    atomic_store(&queue->command, 0);
}
