extends Node

signal resolution_finished(log: Array)

var pile_on_config: PileOnConfigResource = null

func _ready() -> void:
	_ensure_pile_on_config()

func _ensure_pile_on_config() -> void:
	if pile_on_config == null:
		var config_path := "res://data/combat/default_pile_on_config.tres"
		if ResourceLoader.exists(config_path):
			pile_on_config = load(config_path)
		else:
			pile_on_config = PileOnConfigResource.new()

func resolve(all_actions: Array[RoundActions], context: MatchContext) -> Array:
	_ensure_pile_on_config()
	var resolution_log: Array = []

	# Map actions by player_id and sort by player_id ascending for deterministic order
	var sorted_actions: Array[RoundActions] = []
	var action_by_player: Dictionary = {}
	for act in all_actions:
		if act != null:
			sorted_actions.append(act)
			action_by_player[act.player_id] = act
	sorted_actions.sort_custom(func(a: RoundActions, b: RoundActions) -> bool:
		return a.player_id < b.player_id
	)

	# 1. Landscapes
	for action in sorted_actions:
		var kingdom: KingdomState = context.get_kingdom(action.player_id) if context else null
		if kingdom == null or kingdom.is_eliminated:
			continue
		for landscape in action.landscapes_to_play:
			if landscape != null:
				kingdom.landscapes.append(landscape)
				resolution_log.append({
					"step": "landscape",
					"player_id": action.player_id,
					"landscape": landscape,
				})

	# 2. Spells & Floops
	# ponytail: spell resolution deferred to M5
	for action in sorted_actions:
		var kingdom: KingdomState = context.get_kingdom(action.player_id) if context else null
		if kingdom == null or kingdom.is_eliminated:
			continue

		for floop_entry in action.cards_to_floop:
			var card: CardResource = null
			var target_player_id: int = -1

			if floop_entry is CardResource:
				card = floop_entry
			elif floop_entry is Dictionary:
				card = floop_entry.get("card")
				target_player_id = floop_entry.get("target_player_id", -1)

			if card == null:
				continue

			if target_player_id < 0 and context != null:
				target_player_id = context.get_default_opponent_id(action.player_id)

			var opponent: KingdomState = context.get_kingdom(target_player_id) if (context != null and target_player_id >= 0) else null
			var result: Dictionary = FloopResolver.resolve_floop(card, kingdom, opponent)
			resolution_log.append({
				"step": "floop",
				"player_id": action.player_id,
				"target_player_id": target_player_id,
				"card": card,
				"result": result,
			})

			if GameManager and opponent and (opponent.life <= 0 or opponent.is_eliminated):
				GameManager.check_win_condition(context)
				if GameManager.is_match_over:
					break

		if GameManager and GameManager.is_match_over:
			break

	if GameManager and GameManager.is_match_over:
		resolution_finished.emit(resolution_log)
		return resolution_log

	# 3. Creatures
	# 3a. Deploy creatures from hand
	for action in sorted_actions:
		var kingdom: KingdomState = context.get_kingdom(action.player_id) if context else null
		if kingdom == null or kingdom.is_eliminated:
			continue

		for play_data in action.cards_to_play:
			var card: CardResource = play_data.get("card")
			var lane_idx: int = play_data.get("lane", -1)
			if card == null or lane_idx < 0 or lane_idx >= kingdom.lanes.size():
				continue
			if card in kingdom.hand and kingdom.lanes[lane_idx].is_empty() and kingdom.essence >= card.essence_cost:
				kingdom.essence -= card.essence_cost
				kingdom.hand.erase(card)
				kingdom.lanes[lane_idx].append(card)
				resolution_log.append({
					"step": "creature_play",
					"player_id": action.player_id,
					"card": card,
					"lane": lane_idx,
				})

	# 3b. Creature combat attacks across target Kingdoms with pile-on reduction
	if context != null and context.kingdoms.size() >= 2:
		var all_planned_attacks: Array[Dictionary] = []

		# Determine attacks for all active kingdoms
		for kingdom in context.kingdoms:
			if kingdom == null or kingdom.is_eliminated:
				continue
			var pid: int = kingdom.player_id
			var act: RoundActions = action_by_player.get(pid)
			if act != null and not act.attack_targets.is_empty():
				for target_info in act.attack_targets:
					var att_lane: int = target_info.get("attacker_lane", -1)
					var def_id: int = target_info.get("target_player_id", -1)
					var tgt_lane: int = target_info.get("target_lane", -1)
					if tgt_lane < 0:
						tgt_lane = att_lane
					if def_id < 0:
						def_id = context.get_default_opponent_id(pid)
					var has_c: bool = (att_lane >= 0 and att_lane < kingdom.lanes.size() and not kingdom.lanes[att_lane].is_empty())
					all_planned_attacks.append({
						"attacker_id": pid,
						"attacker_lane": att_lane,
						"target_player_id": def_id,
						"target_lane": tgt_lane,
						"has_creature": has_c,
					})
			else:
				var def_id: int = context.get_default_opponent_id(pid)
				for lane_idx in range(3):
					var has_c: bool = (lane_idx < kingdom.lanes.size() and not kingdom.lanes[lane_idx].is_empty())
					all_planned_attacks.append({
						"attacker_id": pid,
						"attacker_lane": lane_idx,
						"target_player_id": def_id,
						"target_lane": lane_idx,
						"has_creature": has_c,
					})

		# Group unique attacking players targeting each defender
		var unique_attackers_per_defender: Dictionary = {}
		for att in all_planned_attacks:
			if not att.has_creature:
				continue
			var def_id: int = att.target_player_id
			if def_id < 0:
				continue
			if not unique_attackers_per_defender.has(def_id):
				unique_attackers_per_defender[def_id] = []
			var att_list: Array = unique_attackers_per_defender[def_id]
			if not (att.attacker_id in att_list):
				att_list.append(att.attacker_id)

		# Compute damage multipliers
		var multiplier_map: Dictionary = {}
		for def_id in unique_attackers_per_defender.keys():
			var att_list: Array = unique_attackers_per_defender[def_id]
			if att_list.size() >= pile_on_config.threshold:
				att_list.sort()
				for idx in range(att_list.size()):
					var att_id: int = att_list[idx]
					multiplier_map["%d:%d" % [def_id, att_id]] = pile_on_config.get_multiplier(idx)
			else:
				for att_id in att_list:
					multiplier_map["%d:%d" % [def_id, att_id]] = 1.0

		# Group attacks by attacker_id and execute in attacker player_id ascending order
		var attacks_by_attacker: Dictionary = {}
		for att in all_planned_attacks:
			var att_id: int = att.attacker_id
			if not attacks_by_attacker.has(att_id):
				attacks_by_attacker[att_id] = []
			attacks_by_attacker[att_id].append(att)

		var attacker_ids: Array = attacks_by_attacker.keys()
		attacker_ids.sort()

		for att_id in attacker_ids:
			var attacker_kingdom: KingdomState = context.get_kingdom(att_id)
			if attacker_kingdom == null or attacker_kingdom.is_eliminated:
				continue

			var attacks_for_att: Array = attacks_by_attacker[att_id]
			for att in attacks_for_att:
				var def_id: int = att.target_player_id
				var defender_kingdom: KingdomState = context.get_kingdom(def_id)
				var key := "%d:%d" % [def_id, att_id]
				var mult: float = multiplier_map.get(key, 1.0)

				var combat_entry: Dictionary = CombatResolver.resolve_attack(
					attacker_kingdom,
					defender_kingdom,
					att.attacker_lane,
					att.target_lane,
					mult
				)
				resolution_log.append(combat_entry)

				if GameManager and defender_kingdom and (defender_kingdom.life <= 0 or defender_kingdom.is_eliminated):
					GameManager.check_win_condition(context)
					if GameManager.is_match_over:
						break

			if GameManager and GameManager.is_match_over:
				break

	if GameManager and GameManager.is_match_over:
		resolution_finished.emit(resolution_log)
		return resolution_log

	# 4. Pact changes
	# ponytail: stub — pact resolution deferred to M4-04
	for action in sorted_actions:
		if not action.pact_proposals.is_empty():
			resolution_log.append({
				"step": "pact_proposal",
				"player_id": action.player_id,
				"proposals": action.pact_proposals,
			})

	# 5. Betrayals
	# ponytail: stub — betrayal resolution deferred to M4-05
	for action in sorted_actions:
		if action.betrayal_target >= 0:
			resolution_log.append({
				"step": "betrayal",
				"player_id": action.player_id,
				"target_player_id": action.betrayal_target,
			})

	resolution_finished.emit(resolution_log)
	return resolution_log
