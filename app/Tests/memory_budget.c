#include "NativeMemoryBudget.h"
#include <assert.h>
#include <stdio.h>
static void check_existing_budget(void){
 assert(pg_streaming_headroom_budget(1000,2000,384)==1000);
 assert(pg_streaming_headroom_budget(1000,600,384)==216);
 assert(pg_streaming_headroom_budget(1000,384,384)==0);
 assert(pg_streaming_headroom_budget(1000,0,384)==0);
 assert(pg_streaming_headroom_budget(0,1000,384)==0);
 assert(pg_streaming_headroom_budget(UINT64_MAX,UINT64_MAX,384)==UINT64_MAX-384);
 assert(pg_streaming_resource_budget(1000,2000,384)==1000);
 assert(pg_streaming_resource_budget(1000,600,384)==216);
 assert(pg_streaming_resource_budget(1000,384,384)==0);
 assert(pg_streaming_resource_budget(1000,100,384)==-284);
 assert(pg_streaming_resource_budget(1000,0,384)==-384);
 assert(pg_streaming_resource_budget(-1000,100,384)==-1000);
 assert(pg_streaming_resource_budget(0,100,384)==-284);
 assert(pg_streaming_resource_budget(INT64_MAX,UINT64_MAX,384)==INT64_MAX);
 assert(pg_streaming_resource_budget(INT64_MAX,0,UINT64_MAX)==INT64_MIN);
 assert(pg_streaming_resource_budget(INT64_MIN,UINT64_MAX,384)==INT64_MIN);
 puts("PASS: native streaming reserve, unsigned heap clamp, signed eviction deficit, original deficit preservation and overflow boundaries.");
}

int main(void) {
    check_existing_budget();
    const uint64_t gib = 1024ull * 1024 * 1024;
    const uint64_t reserve = 512ull * 1024 * 1024;
    assert(pg_process_budget_headroom(9*gib, 3*gib, 8*gib) == 5*gib);
    assert(pg_process_budget_headroom(2*gib, 3*gib, 8*gib) == 2*gib);
    assert(pg_process_budget_headroom(9*gib, 9*gib, 8*gib) == 0);
    assert(pg_process_budget_headroom(9*gib, 3*gib, 0) == 9*gib);
    assert(pg_streaming_headroom_budget(6*gib, 5*gib, reserve) == 5*gib-reserve);
    assert(pg_streaming_headroom_budget(6*gib, 100, reserve) == 0);
    assert(pg_streaming_resource_budget(6*gib, 100, reserve) == -(int64_t)(reserve-100));
    assert(pg_streaming_resource_budget(-100, 5*gib, reserve) == -100);
    assert(pg_process_budget_headroom(UINT64_MAX, UINT64_MAX, 8*gib) == 0);
    puts("EXTREME MEMORY CHECKS PASSED: total ceiling, live iOS allowance, reserve and eviction.");
}
