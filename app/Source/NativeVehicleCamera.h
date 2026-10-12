#pragma once
#include <stdint.h>
#include <stdbool.h>
typedef struct { uint64_t vehicle, camera, lookEpoch; bool held; } PGVehicleCameraHold;
static inline bool pg_vehicle_camera_update(PGVehicleCameraHold *state, bool enabled,
    uint64_t vehicle, uint64_t camera, uint64_t epoch, bool rightStick, bool reset) {
    if (!enabled || !vehicle || !camera) { *state=(PGVehicleCameraHold){0,0,epoch,false}; return false; }
    if (state->vehicle!=vehicle || state->camera!=camera) {
        bool newLook=state->lookEpoch!=epoch;
        *state=(PGVehicleCameraHold){vehicle,camera,epoch,newLook || rightStick};
    } else if (state->lookEpoch!=epoch || rightStick) state->held=true;
    state->lookEpoch=epoch;
    if (reset) state->held=false;
    return state->held;
}
