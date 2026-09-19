extends Node

signal resolution_finished(log: Array)

func resolve(all_actions: Array[RoundActions], context: MatchContext) -> Array:
	var resolution_log: Array = []

	# 1. Landscapes
	# ponytail: stub — landscape resolution deferred to later tasks

	# 2. Spells
	# ponytail: stub — spell resolution deferred to later tasks

	# Process submitted player actions before creature combat
	for action in all_actions:
		if action == null:
			continue
		var kingdom: KingdomState = context.get_kingdom(action.player_id)
		if kingdom == null or kingdom.is_eliminated:
			continue

		# Apply cards_to_play
		for play_data in action.cards_to_play:
			var card: CardResource = play_data.get("card")
			var lane_idx: int = play_data.get("lane", -1)
			if card == null or lane_idx < 0 or lane_idx >= kingdom.lanes.size():
				continue
			if card in kingdom.hand and kingdom.lanes[lane_idx].is_empty() and kingdom.essence >= card.essence_cost:
				kingdom.essence -= card.essence_cost
				kingdom.hand.erase(card)
				kingdom.lanes[lane_idx].append(card)

		# Apply cards_to_floop
		for card in action.cards_to_floop:
			var opponent_id: int = 1 if action.player_id == 0 else 0
			var opponent: KingdomState = context.get_kingdom(opponent_id)
			FloopResolver.resolve_floop(card, kingdom, opponent)

	# 3. Creatures
	if context and context.kingdoms.size() >= 2:
		var p0: KingdomState = context.kingdoms[0]
		var p1: KingdomState = context.kingdoms[1]
		# For 2-player, both players attack each other
		# DECIDED BY PLANNER: sequential both-attack for 2p (p0 first-mover advantage); revisit at M4 simultaneous resolution
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
