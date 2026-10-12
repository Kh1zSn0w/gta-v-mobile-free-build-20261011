#include "NativeVehicleCamera.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
 PGVehicleCameraHold s={0};
 assert(!pg_vehicle_camera_update(&s,true,10,20,0,false,false));
 assert(pg_vehicle_camera_update(&s,true,10,20,1,false,false));
 for(int i=0;i<500;i++) assert(pg_vehicle_camera_update(&s,true,10,20,1,false,false));
 assert(!pg_vehicle_camera_update(&s,true,11,21,1,false,false));
 assert(pg_vehicle_camera_update(&s,true,11,21,2,false,false));
 assert(!pg_vehicle_camera_update(&s,true,11,21,2,false,true));
 assert(!pg_vehicle_camera_update(&s,true,11,21,2,false,false));
 assert(pg_vehicle_camera_update(&s,true,11,21,2,true,false));
 assert(!pg_vehicle_camera_update(&s,false,11,21,3,false,false));
 assert(!pg_vehicle_camera_update(&s,true,11,21,3,false,false));
 assert(!pg_vehicle_camera_update(&s,true,0,0,3,false,false));
 assert(pg_vehicle_camera_update(&s,true,11,21,4,false,false));
 puts("VEHICLE CAMERA CHECKS PASSED: first swipe, stationary hold, vehicle/view reset, explicit look-behind and optional default follow.");
}
