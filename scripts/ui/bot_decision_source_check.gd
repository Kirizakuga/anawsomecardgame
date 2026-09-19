extends Node

var _passed := 0
var _failed := 0
var _manual := 0

var _match_ended_signaled := false
var _signal_winner_id := -999

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CHECK] PASS: %s" % label)
	else:
		_failed += 1
		print("[CHECK] FAIL: %s" % label)

func _on_match_ended(winner_id: int) -> void:
	_match_ended_signaled = true
	_signal_winner_id = winner_id

func _ready() -> void:
	GameManager.match_ended.connect(_on_match_ended)

	# Negative test verification hook
	var args := OS.get_cmdline_args()
	if "--negative-test" in args:
		_check(false, "Simulated intentional failure for negative testing verification")

	_test_interface_parity()
	_test_dummy_ai_swap_parity()
	_test_archetype_compatibility()
	_test_full_match_progression_and_termination()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("BotDecisionSourceCheck: FAIL")
		get_tree().quit(1)
	else:
		print("BotDecisionSourceCheck: PASS")
		get_tree().quit()

func _load_archetype(path: String) -> BotArchetypeResource:
	var res = load(path)
	if res is BotArchetypeResource:
		return res as BotArchetypeResource
	return null

func _create_test_hero(starting_life: int = 20) -> HeroResource:
	var hero := HeroResource.new()
	hero.starting_life = starting_life
	return hero

## 1. Interface Parity
func _test_interface_parity() -> void:
	var bds_default := BotDecisionSource.new()
	_check(bds_default is DecisionSource, "BotDecisionSource inherits from DecisionSource")
	_check(bds_default.has_method("request_actions"), "BotDecisionSource implements request_actions()")
	_check(bds_default.has_signal("actions_ready"), "BotDecisionSource has actions_ready signal")

	var agg_profile = _load_archetype("res://data/bot_profiles/ba_aggressive.tres")
	_check(agg_profile != null, "ba_aggressive archetype loaded")

	var bds_custom := BotDecisionSource.new(agg_profile, 0.0)
	_check(bds_custom.bot_ai != null, "BotDecisionSource initializes bot_ai")
	_check(bds_custom.bot_ai.archetype == agg_profile, "BotDecisionSource sets bot_ai archetype")
	_check(bds_custom.bot_ai.noise_variance == 0.0, "BotDecisionSource sets bot_ai noise_variance")

	var state := KingdomState.new(0)
	state.essence = 5
	var drake: CreatureResource = CardDatabase.get_card("cr_flame_drake") as CreatureResource
	_check(drake != null, "Test card cr_flame_drake loaded")
	if drake != null:
		state.hand.append(drake)

	var received_actions: Array[RoundActions] = []
	bds_custom.actions_ready.connect(func(actions: RoundActions) -> void:
		received_actions.append(actions)
	)

	bds_custom.request_actions(state, MatchContext.new())
	_check(not received_actions.is_empty(), "request_actions emits actions_ready")
	if not received_actions.is_empty():
		var acts: RoundActions = received_actions[0]
		_check(acts.player_id == 0, "Emitted actions matches kingdom player_id")
		_check(acts.cards_to_play.size() == 1, "Emitted actions contains selected card play")

## 2. Direct 2-player match simulation: Swapping BotDecisionSource in for DummyAIDecisionSource
## Requires ZERO changes to ResolutionEngine or TurnManager
func _test_dummy_ai_swap_parity() -> void:
	# Run a turn with DummyAIDecisionSource
	GameManager.reset_match()
	var hero0 := _create_test_hero(20)
	var hero1 := _create_test_hero(20)
	var dummy_source := DummyAIDecisionSource.new()
	var human_source := HumanDecisionSource.new()

	GameManager.setup_match([hero0, hero1], [human_source, dummy_source])
	var context_dummy: MatchContext = GameManager.match_context
	var p0_dummy: KingdomState = context_dummy.kingdoms[0]
	var p1_dummy: KingdomState = context_dummy.kingdoms[1]
	p0_dummy.essence = 2
	p1_dummy.essence = 2

	var scout: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	p0_dummy.hand.append(scout.duplicate())
	p1_dummy.hand.append(scout.duplicate())

	var dummy_actions: Array[RoundActions] = []
	dummy_source.actions_ready.connect(func(acts: RoundActions) -> void:
		dummy_actions.append(acts)
	, CONNECT_ONE_SHOT)
	dummy_source.request_actions(p1_dummy, context_dummy)

	var dummy_log: Array = ResolutionEngine.resolve([RoundActions.new(), dummy_actions[0]], context_dummy)
	_check(dummy_log != null, "ResolutionEngine.resolve() handles DummyAIDecisionSource actions")

	# Now swap in BotDecisionSource in the exact same match structure
	GameManager.reset_match()
	var bot_source := BotDecisionSource.new(null, 0.0)
	GameManager.setup_match([hero0, hero1], [human_source, bot_source])
	var context_bot: MatchContext = GameManager.match_context
	var p0_bot: KingdomState = context_bot.kingdoms[0]
	var p1_bot: KingdomState = context_bot.kingdoms[1]
	p0_bot.essence = 2
	p1_bot.essence = 2

	p0_bot.hand.append(scout.duplicate())
	p1_bot.hand.append(scout.duplicate())

	var bot_actions: Array[RoundActions] = []
	bot_source.actions_ready.connect(func(acts: RoundActions) -> void:
		bot_actions.append(acts)
	, CONNECT_ONE_SHOT)
	bot_source.request_actions(p1_bot, context_bot)

	var bot_log: Array = ResolutionEngine.resolve([RoundActions.new(), bot_actions[0]], context_bot)
	_check(bot_log != null, "ResolutionEngine.resolve() handles BotDecisionSource actions with zero engine changes")
	_check(p1_bot.lanes[bot_actions[0].cards_to_play[0]["lane"]].size() == 1, "BotDecisionSource card successfully resolved into lane")

## 3. Archetype Compatibility (All 4 archetypes)
func _test_archetype_compatibility() -> void:
	var archetype_paths := [
		"res://data/bot_profiles/ba_aggressive.tres",
		"res://data/bot_profiles/ba_opportunist.tres",
		"res://data/bot_profiles/ba_loyalist.tres",
		"res://data/bot_profiles/ba_turtle.tres",
	]

	for path in archetype_paths:
		var profile := _load_archetype(path)
		_check(profile != null, "Archetype loaded: %s" % path.get_file())
		if profile == null:
			continue

		var bds := BotDecisionSource.new(profile, 0.0)
		_check(bds.bot_ai.archetype.id == profile.id, "BotDecisionSource bound to %s" % profile.id)

		# Simulate 3 turns with TurnManager for this archetype
		_run_archetype_match_turns(bds, profile.id)

func _run_archetype_match_turns(bot_source: BotDecisionSource, profile_id: String) -> void:
	GameManager.reset_match()
	var hero0 := _create_test_hero(25)
	var hero1 := _create_test_hero(25)
	var human_source := HumanDecisionSource.new()

	GameManager.setup_match([hero0, hero1], [human_source, bot_source])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	var cards: Array[CardResource] = [
		CardDatabase.get_card("cr_goblin_scout"),
		CardDatabase.get_card("cr_stone_golem"),
		CardDatabase.get_card("cr_flame_drake"),
		CardDatabase.get_card("cr_ancient_treant")
	]

	for i in range(8):
		p0.deck.append(cards[i % cards.size()].duplicate())
		p1.deck.append(cards[i % cards.size()].duplicate())

	TurnManager.current_turn = 0
	var legal_actions := true

	for turn_idx in range(3):
		TurnManager.start_turn() # Phase.ESSENCE
		context.turn_number = TurnManager.current_turn
		p0.essence += 2
		p1.essence += 2
		if not p0.deck.is_empty():
			p0.hand.append(p0.deck.pop_front())
		if not p1.deck.is_empty():
			p1.hand.append(p1.deck.pop_front())

		TurnManager.next_phase() # Phase.PLAY
		var bot_received: Array[RoundActions] = []
		bot_source.actions_ready.connect(func(acts: RoundActions) -> void:
			bot_received.append(acts)
		, CONNECT_ONE_SHOT)
		bot_source.request_actions(p1, context)

		if bot_received.is_empty():
			legal_actions = false
			break

		var bot_act: RoundActions = bot_received[0]
		# Check legality
		var total_cost := 0
		for play in bot_act.cards_to_play:
			var card: CardResource = play.get("card")
			var lane: int = play.get("lane", -1)
			total_cost += card.essence_cost
			if not (card in p1.hand) or not p1.lanes[lane].is_empty():
				legal_actions = false
		for floop in bot_act.cards_to_floop:
			total_cost += floop.floop_effect.cost_amount
		if total_cost > p1.essence:
			legal_actions = false

		TurnManager.next_phase() # Phase.BATTLE
		ResolutionEngine.resolve([RoundActions.new(), bot_act], context)

		TurnManager.next_phase() # Phase.CLEANUP

	_check(legal_actions, "Archetype %s: all requested actions strictly legal across 3 turns" % profile_id)

## 4. Full Match Progression & Clean Termination
func _test_full_match_progression_and_termination() -> void:
	GameManager.reset_match()
	_match_ended_signaled = false
	_signal_winner_id = -999

	var agg_profile := _load_archetype("res://data/bot_profiles/ba_aggressive.tres")
	var tur_profile := _load_archetype("res://data/bot_profiles/ba_turtle.tres")

	var hero0 := _create_test_hero(15)
	var hero1 := _create_test_hero(15)

	var bot0 := BotDecisionSource.new(agg_profile, 0.05)
	var bot1 := BotDecisionSource.new(tur_profile, 0.05)

	GameManager.setup_match([hero0, hero1], [bot0, bot1])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	var cards: Array[CardResource] = [
		CardDatabase.get_card("cr_flame_drake"),
		CardDatabase.get_card("cr_goblin_scout"),
		CardDatabase.get_card("cr_stone_golem")
	]

	for i in range(15):
		p0.deck.append(cards[i % cards.size()].duplicate())
		p1.deck.append(cards[i % cards.size()].duplicate())

	TurnManager.current_turn = 0
	var turns_executed := 0

	while not GameManager.is_match_over and context.turn_number < context.turn_limit:
		turns_executed += 1
		TurnManager.start_turn() # Phase.ESSENCE
		context.turn_number = TurnManager.current_turn

		p0.essence += mini(context.turn_number, 5)
		p1.essence += mini(context.turn_number, 5)

		if not p0.deck.is_empty():
			p0.hand.append(p0.deck.pop_front())
		if not p1.deck.is_empty():
			p1.hand.append(p1.deck.pop_front())

		TurnManager.next_phase() # Phase.PLAY
		var p0_acts: Array[RoundActions] = []
		var p1_acts: Array[RoundActions] = []

		bot0.actions_ready.connect(func(a: RoundActions) -> void: p0_acts.append(a), CONNECT_ONE_SHOT)
		bot1.actions_ready.connect(func(a: RoundActions) -> void: p1_acts.append(a), CONNECT_ONE_SHOT)

		bot0.request_actions(p0, context)
		bot1.request_actions(p1, context)

		TurnManager.next_phase() # Phase.BATTLE
		var a0: RoundActions = p0_acts[0] if not p0_acts.is_empty() else RoundActions.new()
		var a1: RoundActions = p1_acts[0] if not p1_acts.is_empty() else RoundActions.new()
		ResolutionEngine.resolve([a0, a1], context)

		TurnManager.next_phase() # Phase.CLEANUP
		GameManager.check_win_condition(context)

	_check(turns_executed > 0, "Match executed turns (total: %d)" % turns_executed)
	_check(GameManager.is_match_over, "Match terminated cleanly (is_match_over is true)")
	_check(_match_ended_signaled, "GameManager.match_ended signal emitted on termination")
	_check(GameManager.winner in [-1, 0, 1], "Valid winner ID declared (%d)" % GameManager.winner)
	_check(_signal_winner_id == GameManager.winner, "Signal winner (%d) matches GameManager.winner (%d)" % [_signal_winner_id, GameManager.winner])
