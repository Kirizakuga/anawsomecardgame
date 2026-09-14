class_name BotDecisionSource
extends DecisionSource

var bot_ai: BotAI

func _init(archetype: BotArchetypeResource = null) -> void:
	bot_ai = BotAI.new(archetype)

func request_actions(kingdom: KingdomState, context: MatchContext) -> void:
	var actions := bot_ai.decide(kingdom, context)
	actions_ready.emit(actions)
