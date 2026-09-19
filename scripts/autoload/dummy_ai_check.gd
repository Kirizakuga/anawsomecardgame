extends Node

var _passed := 0
var _failed := 0

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CHECK] PASS: %s" % label)
	else:
		_failed += 1
		print("[CHECK] FAIL: %s" % label)

func _ready() -> void:
	_test_dummy_ai_legality_and_decision()
	_test_dummy_ai_insufficient_essence()
	_test_dummy_ai_full_lanes()
	_test_simulated_matches()

	print("[CHECK] SUMMARY: %d passed, %d failed, 0 manual" % [_passed, _failed])
	if _failed > 0:
		print("DummyAICheck: FAIL")
		get_tree().quit(1)
	else:
		print("DummyAICheck: PASS")
		get_tree().quit()

func _test_dummy_ai_legality_and_decision() -> void:
	var ai := DummyAIDecisionSource.new()
	var state := KingdomState.new(1)
	state.essence = 5

	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	var drake: CreatureResource = CardDatabase.get_card("cr_flame_drake") as CreatureResource
	var treant: CreatureResource = CardDatabase.get_card("cr_ancient_treant") as CreatureResource
	_check(goblin != null and drake != null and treant != null, "Unit test cards loaded")

	state.hand.append(goblin)
	state.hand.append(drake)
	state.hand.append(treant)

	var received: Array[RoundActions] = []
	ai.actions_ready.connect(func(acts: RoundActions) -> void:
		received.append(acts)
	)

	ai.request_actions(state, MatchContext.new())

	_check(not received.is_empty(), "DummyAI emits actions_ready")
	if received.is_empty():
		return

	var emitted_actions: RoundActions = received[0]
	_check(emitted_actions.player_id == 1, "Emitted actions has correct player_id")

	var total_cost := 0
	var used_lanes: Array[int] = []
	var legal_plays := true

	for play in emitted_actions.cards_to_play:
		var c: CardResource = play.get("card")
		var l: int = play.get("lane", -1)
		total_cost += c.essence_cost
		if l in used_lanes or l < 0 or l >= 3:
			legal_plays = false
		used_lanes.append(l)

	_check(total_cost <= 5, "Total cost of played cards (%d) does not exceed starting essence (5)" % total_cost)
	_check(legal_plays, "Played cards assigned to unique, valid lanes (0..2)")

func _test_dummy_ai_insufficient_essence() -> void:
	var ai := DummyAIDecisionSource.new()
	var state := KingdomState.new(1)
	state.essence = 0

	var drake: CreatureResource = CardDatabase.get_card("cr_flame_drake") as CreatureResource
	state.hand.append(drake)

	var received: Array[RoundActions] = []
	ai.actions_ready.connect(func(acts: RoundActions) -> void:
		received.append(acts)
	)

	ai.request_actions(state, MatchContext.new())

	_check(not received.is_empty() and received[0].cards_to_play.is_empty(), "DummyAI makes no plays when essence is 0 and card is unaffordable")

func _test_dummy_ai_full_lanes() -> void:
	var ai := DummyAIDecisionSource.new()
	var state := KingdomState.new(1)
	state.essence = 10

	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	for i in range(3):
		state.lanes[i].append(goblin)
	state.hand.append(goblin)

	var received: Array[RoundActions] = []
	ai.actions_ready.connect(func(acts: RoundActions) -> void:
		received.append(acts)
	)

	ai.request_actions(state, MatchContext.new())

	_check(not received.is_empty() and received[0].cards_to_play.is_empty(), "DummyAI makes no plays when all lanes are full")

func _test_simulated_matches() -> void:
	for match_idx in range(3):
		_run_single_match(match_idx + 1)

func _run_single_match(match_num: int) -> void:
	var hero: HeroResource = HeroResource.new()
	hero.starting_life = 20

	var p0_source := HumanDecisionSource.new()
	var p1_source := DummyAIDecisionSource.new()

	GameManager.setup_match([hero, hero], [p0_source, p1_source])
	var context: MatchContext = GameManager.match_context

	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	# Setup decks for both players
	var card_pool: Array[CardResource] = [
		CardDatabase.get_card("cr_goblin_scout"),
		CardDatabase.get_card("cr_flame_drake"),
		CardDatabase.get_card("cr_stone_golem"),
		CardDatabase.get_card("cr_ancient_treant"),
	]

	for i in range(12):
		p0.deck.append(card_pool[i % card_pool.size()].duplicate())
		p1.deck.append(card_pool[i % card_pool.size()].duplicate())

	var match_completed_cleanly := false
	var no_invalid_actions := true

	# Run turns
	while context.turn_number < context.turn_limit and not p0.is_eliminated and not p1.is_eliminated:
		context.turn_number += 1

		# Essence scaling
		var turn_essence: int = mini(context.turn_number, 5)
		p0.essence += turn_essence
		p1.essence += turn_essence

		# Card draw
		if not p0.deck.is_empty():
			p0.hand.append(p0.deck.pop_front())
		if not p1.deck.is_empty():
			p1.hand.append(p1.deck.pop_front())

		# P0 (Human) requests & queues affordable plays
		p0_source.request_actions(p0, context)
		var p0_remaining_essence := p0.essence
		var p0_hand_copy := p0.hand.duplicate()
		for card in p0_hand_copy:
			if card is CreatureResource and card.essence_cost <= p0_remaining_essence:
				for lane_idx in range(p0.lanes.size()):
					if p0.lanes[lane_idx].is_empty():
						p0_source.queue_card_play(card, lane_idx)
						p0_remaining_essence -= card.essence_cost
						break

		var p0_received: Array[RoundActions] = []
		p0_source.actions_ready.connect(func(acts: RoundActions) -> void:
			p0_received.append(acts)
		, CONNECT_ONE_SHOT)
		p0_source.submit()

		# P1 (Dummy AI) requests actions
		var p1_received: Array[RoundActions] = []
		p1_source.actions_ready.connect(func(acts: RoundActions) -> void:
			p1_received.append(acts)
		, CONNECT_ONE_SHOT)
		p1_source.request_actions(p1, context)

		var p0_actions: RoundActions = p0_received[0] if not p0_received.is_empty() else null
		var p1_actions: RoundActions = p1_received[0] if not p1_received.is_empty() else null

		if p1_actions == null:
			no_invalid_actions = false
			break

		# Verify legality of Dummy AI actions before execution
		var p1_play_cost := 0
		var p1_lanes_used: Array[int] = []
		for play in p1_actions.cards_to_play:
			var card: CardResource = play.get("card")
			var lane_idx: int = play.get("lane", -1)
			p1_play_cost += card.essence_cost
			if not (card in p1.hand) or not p1.lanes[lane_idx].is_empty() or lane_idx in p1_lanes_used:
				no_invalid_actions = false
			p1_lanes_used.append(lane_idx)
		if p1_play_cost > p1.essence:
			no_invalid_actions = false

		# ResolutionEngine resolves
		ResolutionEngine.resolve([p0_actions, p1_actions], context)

		# Check win condition
		var winner: int = GameManager.check_win_condition()
		if winner != -1 or p0.is_eliminated or p1.is_eliminated or context.is_turn_limit_reached():
			match_completed_cleanly = true
			break

	if not match_completed_cleanly and context.is_turn_limit_reached():
		match_completed_cleanly = true

	_check(match_completed_cleanly, "Match %d completed cleanly without crash or infinite loop" % match_num)
	_check(no_invalid_actions, "Match %d: all Dummy AI moves were strictly legal" % match_num)
	_check(p0.life is int and p1.life is int and (p0.is_eliminated or p0.life > 0) and (p1.is_eliminated or p1.life > 0), "Match %d: life totals and elimination state remained valid" % match_num)
