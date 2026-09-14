class_name BotAI
extends RefCounted

var archetype: BotArchetypeResource

func _init(p_archetype: BotArchetypeResource = null) -> void:
	archetype = p_archetype

func decide(kingdom: KingdomState, context: MatchContext) -> RoundActions:
	var actions := RoundActions.new()
	actions.player_id = kingdom.player_id
	# ponytail: stub — scoring logic in Phase 3
	return actions
