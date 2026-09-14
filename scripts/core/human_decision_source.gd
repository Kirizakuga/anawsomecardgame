class_name HumanDecisionSource
extends DecisionSource

var pending_actions: RoundActions

func request_actions(kingdom: KingdomState, _context: MatchContext) -> void:
	pending_actions = RoundActions.new()
	pending_actions.player_id = kingdom.player_id
	# ponytail: stub — UI hooks fill pending_actions, then call submit()

func submit() -> void:
	actions_ready.emit(pending_actions)
