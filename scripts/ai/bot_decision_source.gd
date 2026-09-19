class_name BotDecisionSource
extends DecisionSource

var bot_ai: BotAI

func _init(archetype: BotArchetypeResource = null, noise_variance: float = 0.05) -> void:
	bot_ai = BotAI.new(archetype, noise_variance)

func request_actions(kingdom: KingdomState, context: MatchContext) -> void:
	var actions := bot_ai.decide(kingdom, context)
	actions_ready.emit(actions)
