class_name DummyAIDecisionSource
extends DecisionSource

## Temporary stand-in for BotDecisionSource (M1-07).
## Picks random legal actions each phase. Pure RefCounted, zero Node dependencies.

func request_actions(kingdom: KingdomState, _context: MatchContext) -> void:
	var actions := RoundActions.new()
	actions.player_id = kingdom.player_id

	var remaining_essence: int = kingdom.essence

	# 1. Identify empty lanes
	var empty_lanes: Array[int] = []
	for lane_idx in range(kingdom.lanes.size()):
		if kingdom.lanes[lane_idx].is_empty():
			empty_lanes.append(lane_idx)
	empty_lanes.shuffle()

	# 2. Select creature cards from hand that can be afforded
	var candidate_cards: Array[CardResource] = []
	for card in kingdom.hand:
		if card is CreatureResource and card.essence_cost <= remaining_essence:
			candidate_cards.append(card)
	candidate_cards.shuffle()

	# 3. Play cards into empty lanes without exceeding remaining essence
	var hand_copy: Array[CardResource] = kingdom.hand.duplicate()
	for card in candidate_cards:
		if empty_lanes.is_empty():
			break
		if card.essence_cost <= remaining_essence and card in hand_copy:
			var lane_idx: int = empty_lanes.pop_back()
			actions.cards_to_play.append({"card": card, "lane": lane_idx})
			remaining_essence -= card.essence_cost
			hand_copy.erase(card)

	# 4. Optional floops for creatures currently in play in kingdom.lanes
	for lane_idx in range(kingdom.lanes.size()):
		var lane: Array = kingdom.lanes[lane_idx]
		if not lane.is_empty():
			var creature: CreatureResource = lane[0] as CreatureResource
			if creature and creature.floop_effect != null:
				var cost: int = creature.floop_effect.cost_amount
				if remaining_essence >= cost:
					# 50% random chance or always floop if affordable
					if randf() > 0.3:
						actions.cards_to_floop.append(creature)
						remaining_essence -= cost

	actions_ready.emit(actions)
