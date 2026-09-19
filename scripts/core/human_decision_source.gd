class_name HumanDecisionSource
extends DecisionSource

var pending_actions: RoundActions = null

func request_actions(kingdom: KingdomState, _context: MatchContext) -> void:
	pending_actions = RoundActions.new()
	pending_actions.player_id = kingdom.player_id

func queue_card_play(card: CardResource, lane_index: int) -> void:
	_ensure_pending_actions()
	pending_actions.cards_to_play.append({"card": card, "lane": lane_index})

func queue_floop(card: CardResource) -> void:
	_ensure_pending_actions()
	pending_actions.cards_to_floop.append(card)

func queue_landscape(landscape: LandscapeResource) -> void:
	_ensure_pending_actions()
	pending_actions.landscapes_to_play.append(landscape)

func queue_attack_target(attacker_lane: int, target_player_id: int, target_lane: int = -1) -> void:
	_ensure_pending_actions()
	pending_actions.attack_targets.append({
		"attacker_lane": attacker_lane,
		"target_player_id": target_player_id,
		"target_lane": target_lane,
	})

func queue_pact_proposal(target_player_id: int, terms: Dictionary = {}) -> void:
	_ensure_pending_actions()
	pending_actions.pact_proposals.append({
		"target_player_id": target_player_id,
		"terms": terms,
	})

func queue_betrayal(target_player_id: int) -> void:
	_ensure_pending_actions()
	pending_actions.betrayal_target = target_player_id

func clear_actions() -> void:
	if pending_actions != null:
		pending_actions.cards_to_play.clear()
		pending_actions.cards_to_floop.clear()
		pending_actions.landscapes_to_play.clear()
		pending_actions.attack_targets.clear()
		pending_actions.pact_proposals.clear()
		pending_actions.betrayal_target = -1

func submit() -> void:
	_ensure_pending_actions()
	actions_ready.emit(pending_actions)

func _ensure_pending_actions() -> void:
	if pending_actions == null:
		pending_actions = RoundActions.new()
