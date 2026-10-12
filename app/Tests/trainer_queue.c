#include "NativeTrainer.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    PGTrainerQueue queue = {0};
    assert(!pg_trainer_submit(&queue, PG_TRAINER_HEALTH, 0));
    assert(!pg_trainer_take(&queue, true, 0));
    assert(!pg_trainer_submit(&queue, 0, 0));
    assert(!pg_trainer_submit(&queue, 182, 0));
    for (uint32_t command = 1; command <= 181; command++) {
        assert(pg_trainer_submit(&queue, command, 10));
        assert(atomic_load(&queue.status) == PG_TRAINER_PENDING);
        assert(!pg_trainer_submit(&queue, 1, 11));
        assert(pg_trainer_take(&queue, true, 11) == command);
        assert(!pg_trainer_submit(&queue, 1, 11));
        pg_trainer_finish(&queue);
        assert(atomic_load(&queue.status) == PG_TRAINER_HANDLED);
        assert(!pg_trainer_take(&queue, true, 12));
    }
    assert(pg_trainer_submit(&queue, 1, 20));
    assert(!pg_trainer_take(&queue, true, 26));
    assert(atomic_load(&queue.status) == PG_TRAINER_EXPIRED);
    assert(!pg_trainer_take(&queue, true, 27));
    assert(pg_trainer_submit(&queue, 2, 30));
    assert(!pg_trainer_take(&queue, false, 31));
    assert(atomic_load(&queue.status) == PG_TRAINER_UNAVAILABLE);
    assert(!pg_trainer_take(&queue, true, 32));
    puts("TRAINER QUEUE CHECKS PASSED: 181 commands, no overwrites, no replay, readiness and expiry.");
}
