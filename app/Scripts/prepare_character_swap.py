"""Apply narrowly scoped guards to the pinned player-model-change function."""

def patch_player_model_change(function):
    flush = '  w2c_game_f5315(instance, var_i0);'
    guarded_flush = '  if (!pg_wardrobe_preloaded_swap()) w2c_game_f5315(instance, var_i0);'
    if guarded_flush not in function:
        if function.count(flush) != 1 or 'w2c_game_f47995(' not in function:
            raise RuntimeError('Pinned character-change streaming prerequisite changed')
        function = function.replace(flush, guarded_flush, 1)
    handoff = '  var_j0 = var_l3;\n  var_i1 = 1u;\n  var_j0 = w2c_game_f45797(instance, var_j0, var_i1);'
    guarded_handoff = '  if (!pg_wardrobe_script_handoff_ready(var_l3)) goto var_B1;\n' + handoff
    if guarded_handoff not in function:
        if function.count(handoff) != 1 or function.count('  var_B1:;') != 1:
            raise RuntimeError('Pinned character script-task handoff changed')
        function = function.replace(handoff, guarded_handoff, 1)
    resolved = '  var_j0 = w2c_game_f45797(instance, var_j0, var_i1);\n  var_l3 = var_j0;'
    guarded_result = resolved + '\n  if (pg_wardrobe_preloaded_swap() && !var_l3) goto var_B1;'
    if guarded_result not in function:
        if function.count(resolved) != 1:
            raise RuntimeError('Pinned character motion-task result changed')
        function = function.replace(resolved, guarded_result, 1)
    return function
