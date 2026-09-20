class_name BotAI
extends RefCounted

var archetype: BotArchetypeResource
var noise_variance: float = 0.05

func _init(p_archetype: BotArchetypeResource = null, p_noise_variance: float = 0.05) -> void:
	archetype = p_archetype
	noise_variance = p_noise_variance

## Scores placing a creature card into a specific lane.
## Follows TDD §3.5: score(action) = Σ (weight_i * feature_i(action, board_state))
func score_card_placement(card: CreatureResource, lane_idx: int, kingdom: KingdomState, context: MatchContext, with_noise: bool = true) -> float:
	if card == null:
		return 0.0

	var agg_w: float = archetype.aggression_weight if archetype else 1.0
	var def_w: float = archetype.defense_weight if archetype else 1.0

	# 1. Base stat features
	var f_atk: float = float(card.attack)
	var f_def: float = float(card.defense)
	var score: float = (agg_w * f_atk) + (def_w * f_def)

	# 2. Threat context features
	var opp_creature: CreatureResource = _get_opposing_creature(lane_idx, kingdom, context)
	if opp_creature == null:
		# Empty opposing lane: direct kingdom attack opportunity favors aggression
		var f_direct: float = float(card.attack)
		score += agg_w * f_direct
	else:
		# Opposing creature present: need to block / absorb damage favors defense
		var f_block: float = float(card.defense + opp_creature.attack)
		score += def_w * f_block

	if with_noise and noise_variance > 0.0:
		score += randf_range(-noise_variance, noise_variance)

	return score

## Scores activating a creature's floop effect.
## Evaluates effect type against archetype weights (aggression/defense) scaled by floop_preference_weight.
func score_floop(card: CardResource, _kingdom: KingdomState, _context: MatchContext, with_noise: bool = true) -> float:
	if card == null or card.floop_effect == null:
		return 0.0

	var effect: FloopEffectResource = card.floop_effect
	var floop_w: float = archetype.floop_preference_weight if archetype else 1.0
	var agg_w: float = archetype.aggression_weight if archetype else 1.0
	var def_w: float = archetype.defense_weight if archetype else 1.0

	var effect_score: float = 0.0
	match effect.effect_type:
		"direct_damage":
			effect_score = agg_w * float(effect.effect_value)
		"buff_attack":
			effect_score = agg_w * float(effect.effect_value)
		"heal_life":
			effect_score = def_w * float(effect.effect_value)
		"draw_card":
			effect_score = 1.5 * float(effect.effect_value)
		_:
			effect_score = float(effect.effect_value)

	var score: float = floop_w * effect_score
	if with_noise and noise_variance > 0.0:
		score += randf_range(-noise_variance, noise_variance)

	return score

## Generates candidate actions and scores via the weighted-sum formula in TDD §3.5.
## Returns highest-scoring RoundActions within essence budget.
# ponytail: greedy candidate selection within essence budget; upgrade to combinatorial search when multi-card synergies arrive in M4/M5.
func decide(kingdom: KingdomState, context: MatchContext) -> RoundActions:
	var actions := RoundActions.new()
	if kingdom == null or kingdom.is_eliminated:
		return actions

	actions.player_id = kingdom.player_id
	var remaining_essence: int = kingdom.essence

	# 1. Available empty lanes
	var available_lanes: Array[int] = []
	for i in range(kingdom.lanes.size()):
		if kingdom.lanes[i].is_empty():
			available_lanes.append(i)

	# 2. Available cards in hand
	var available_hand: Array[CardResource] = kingdom.hand.duplicate()

	# 3. Floop candidates from creatures currently on board
	var floop_candidates: Array[CreatureResource] = []
	for i in range(kingdom.lanes.size()):
		var lane: Array = kingdom.lanes[i]
		if not lane.is_empty() and lane[0] is CreatureResource:
			var creature: CreatureResource = lane[0] as CreatureResource
			if creature.floop_effect != null and creature.floop_effect.cost_type == "essence":
				floop_candidates.append(creature)

	# 4. Iteratively select highest-scoring candidate action within budget
	while remaining_essence > 0:
		var best_action: Dictionary = {}
		var best_score: float = -INF

		# Evaluate play candidates
		if not available_lanes.is_empty():
			for card in available_hand:
				if not (card is CreatureResource):
					continue
				if card.essence_cost > remaining_essence:
					continue
				for lane_idx in available_lanes:
					var s: float = score_card_placement(card as CreatureResource, lane_idx, kingdom, context)
					if s > best_score:
						best_score = s
						best_action = {
							"type": "play",
							"card": card,
							"lane": lane_idx,
							"cost": card.essence_cost,
							"score": s
						}

		# Evaluate floop candidates
		for card in floop_candidates:
			var cost: int = card.floop_effect.cost_amount
			if cost > remaining_essence:
				continue
			var s: float = score_floop(card, kingdom, context)
			if s > best_score:
				best_score = s
				best_action = {
					"type": "floop",
					"card": card,
					"cost": cost,
					"score": s
				}

		if best_action.is_empty():
			break

		# Apply best action
		if best_action["type"] == "play":
			actions.cards_to_play.append({"card": best_action["card"], "lane": best_action["lane"]})
			remaining_essence -= best_action["cost"]
			available_hand.erase(best_action["card"])
			available_lanes.erase(best_action["lane"])
			var played_c: CreatureResource = best_action["card"] as CreatureResource
			if played_c.floop_effect != null and played_c.floop_effect.cost_type == "essence":
				floop_candidates.append(played_c)
		elif best_action["type"] == "floop":
			actions.cards_to_floop.append(best_action["card"])
			remaining_essence -= best_action["cost"]
			floop_candidates.erase(best_action["card"])

	return actions

func _get_opposing_creature(lane_idx: int, kingdom: KingdomState, context: MatchContext) -> CreatureResource:
	if context == null or kingdom == null:
		return null
	for k in context.kingdoms:
		if k != null and k.player_id != kingdom.player_id and not k.is_eliminated:
			if lane_idx >= 0 and lane_idx < k.lanes.size():
				var lane: Array = k.lanes[lane_idx]
				if not lane.is_empty() and lane[0] is CreatureResource:
					return lane[0] as CreatureResource
	return null
