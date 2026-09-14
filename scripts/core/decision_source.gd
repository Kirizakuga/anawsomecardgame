class_name DecisionSource
extends RefCounted

signal actions_ready(actions: RoundActions)

func request_actions(_kingdom: KingdomState, _context: MatchContext) -> void:
	push_error('DecisionSource.request_actions() not implemented')
