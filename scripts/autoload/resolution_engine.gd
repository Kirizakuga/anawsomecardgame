extends Node

signal resolution_finished(log: Array)

func resolve(all_actions: Array[RoundActions], context: MatchContext) -> Array:
	var resolution_log: Array = []

	# 1. Landscapes
	# ponytail: stub — landscape resolution deferred to later tasks

	# 2. Spells
	# ponytail: stub — spell resolution deferred to later tasks

	# 3. Creatures
	if context and context.kingdoms.size() >= 2:
		var p0: KingdomState = context.kingdoms[0]
		var p1: KingdomState = context.kingdoms[1]
		# For 2-player, both players attack each other
		# ponytail: sequential attack pass for 2p; p0 attacks p1, then p1 attacks p0 until M4 targeting/simultaneous resolution
		var p0_combat: Array[Dictionary] = CombatResolver.resolve_combat(p0, p1)
		resolution_log.append_array(p0_combat)
		var p1_combat: Array[Dictionary] = CombatResolver.resolve_combat(p1, p0)
		resolution_log.append_array(p1_combat)

	# 4. Pact changes
	# ponytail: stub — pact resolution deferred to M4

	# 5. Betrayals
	# ponytail: stub — betrayal resolution deferred to M4

	resolution_finished.emit(resolution_log)
	return resolution_log
