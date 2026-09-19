extends Node

var _passed := 0
var _failed := 0

var _signal_emissions := 0
var _signal_winner := -999

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CHECK] PASS: %s" % label)
	else:
		_failed += 1
		print("[CHECK] FAIL: %s" % label)

func _ready() -> void:
	GameManager.match_ended.connect(_on_match_ended)

	_test_combat_damage_win_condition()
	_test_floop_direct_damage_win_condition()
	_test_turn_limit_reached_highest_life()
	_test_no_double_trigger()
	_test_both_players_alive_no_winner()
	_test_direct_life_reduction_elimination()

	print("[CHECK] SUMMARY: %d passed, %d failed, 0 manual" % [_passed, _failed])
	if _failed > 0:
		print("WinConditionCheck: FAIL")
		get_tree().quit(1)
	else:
		print("WinConditionCheck: PASS")
		get_tree().quit()

func _on_match_ended(winner_id: int) -> void:
	_signal_emissions += 1
	_signal_winner = winner_id

func _reset_signal_tracker() -> void:
	_signal_emissions = 0
	_signal_winner = -999

func _create_hero(starting_life: int) -> HeroResource:
	var hero := HeroResource.new()
	hero.starting_life = starting_life
	return hero

func _test_combat_damage_win_condition() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(25)
	var hero1 := _create_hero(5)
	var s0 := HumanDecisionSource.new()
	var s1 := DummyAIDecisionSource.new()

	GameManager.setup_match([hero0, hero1], [s0, s1])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	# Place creature with ATK 10 in p0 lane 0; p1 lane 0 empty -> deals 10 unblocked damage to p1 (life 5 -> -5)
	var attacker := CreatureResource.new()
	attacker.id = "strong_attacker"
	attacker.attack = 10
	attacker.defense = 5
	p0.lanes[0].append(attacker)

	ResolutionEngine.resolve([], context)

	_check(p1.life <= 0, "Test 1 - Combat damage reduced opponent life to <= 0 (life: %d)" % p1.life)
	_check(p1.is_eliminated, "Test 1 - Opponent is_eliminated marked true after lethal combat damage")
	_check(GameManager.is_match_over, "Test 1 - GameManager.is_match_over is true")
	_check(GameManager.winner == 0, "Test 1 - GameManager.winner declared player 0")
	_check(_signal_emissions == 1, "Test 1 - match_ended signal emitted exactly once (count: %d)" % _signal_emissions)
	_check(_signal_winner == 0, "Test 1 - match_ended signal emitted winner_id 0")

func _test_floop_direct_damage_win_condition() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(20)
	var hero1 := _create_hero(2)
	var s0 := HumanDecisionSource.new()
	var s1 := DummyAIDecisionSource.new()

	GameManager.setup_match([hero0, hero1], [s0, s1])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	# cr_flame_drake floop deals 2 direct damage, costing 2 essence
	var drake := CardDatabase.get_card("cr_flame_drake") as CreatureResource
	_check(drake != null and drake.floop_effect != null, "Test 2 - cr_flame_drake loaded with floop effect")
	if drake == null or drake.floop_effect == null:
		return

	p0.essence = 5
	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.cards_to_floop.append(drake)
	var act1 := RoundActions.new()
	act1.player_id = 1

	ResolutionEngine.resolve([act0, act1], context)

	_check(p1.life <= 0, "Test 2 - Floop direct damage reduced opponent life to <= 0 (life: %d)" % p1.life)
	_check(p1.is_eliminated, "Test 2 - Opponent is_eliminated marked true after lethal floop damage")
	_check(GameManager.is_match_over, "Test 2 - GameManager.is_match_over is true")
	_check(GameManager.winner == 0, "Test 2 - GameManager.winner declared player 0")
	_check(_signal_emissions == 1, "Test 2 - match_ended signal emitted exactly once (count: %d)" % _signal_emissions)
	_check(_signal_winner == 0, "Test 2 - match_ended signal emitted winner_id 0")

func _test_turn_limit_reached_highest_life() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(20)
	var hero1 := _create_hero(14)
	var s0 := HumanDecisionSource.new()
	var s1 := DummyAIDecisionSource.new()

	GameManager.setup_match([hero0, hero1], [s0, s1])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	context.turn_number = context.turn_limit
	var declared: int = GameManager.check_win_condition()

	_check(declared == 0, "Test 3 - Turn limit reached declared player 0 as winner by highest life (20 > 14)")
	_check(GameManager.is_match_over, "Test 3 - GameManager.is_match_over is true")
	_check(GameManager.winner == 0, "Test 3 - GameManager.winner is 0")
	_check(_signal_emissions == 1, "Test 3 - match_ended signal emitted exactly once (count: %d)" % _signal_emissions)
	_check(_signal_winner == 0, "Test 3 - match_ended signal emitted winner_id 0")

	# Subtest: Tie at turn limit
	_reset_signal_tracker()
	var hero_tie0 := _create_hero(15)
	var hero_tie1 := _create_hero(15)
	GameManager.setup_match([hero_tie0, hero_tie1], [HumanDecisionSource.new(), DummyAIDecisionSource.new()])
	var tie_ctx: MatchContext = GameManager.match_context
	tie_ctx.turn_number = tie_ctx.turn_limit

	var tie_declared: int = GameManager.check_win_condition()
	_check(tie_declared == -1, "Test 3 - Tie in life totals at turn limit resolves to draw (-1)")
	_check(GameManager.is_match_over, "Test 3 - Tie ends match (is_match_over is true)")
	_check(_signal_emissions == 1, "Test 3 - match_ended emitted once on tie (count: %d)" % _signal_emissions)
	_check(_signal_winner == -1, "Test 3 - match_ended emitted -1 on tie")

func _test_no_double_trigger() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(25)
	var hero1 := _create_hero(5)
	GameManager.setup_match([hero0, hero1], [HumanDecisionSource.new(), DummyAIDecisionSource.new()])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	# Eliminate p1
	p1.life = 0
	var first_res: int = GameManager.check_win_condition()
	_check(first_res == 0, "Test 4 - Initial check_win_condition ended match with winner 0")
	_check(_signal_emissions == 1, "Test 4 - First trigger emitted match_ended exactly once")

	# Subsequent check_win_condition calls
	var second_res: int = GameManager.check_win_condition()
	var third_res: int = GameManager.check_win_condition()
	_check(second_res == 0 and third_res == 0, "Test 4 - Subsequent check_win_condition calls return winner 0")
	_check(_signal_emissions == 1, "Test 4 - Subsequent check_win_condition calls did NOT re-emit match_ended")

	# Attempt to end match manually with a different winner
	GameManager.end_match(1)
	_check(_signal_emissions == 1, "Test 4 - GameManager.end_match(1) after match over did NOT re-emit match_ended")
	_check(GameManager.winner == 0, "Test 4 - Winner was NOT overwritten by end_match call")

	# Subsequent ResolutionEngine.resolve() with additional damage
	p1.life -= 20
	ResolutionEngine.resolve([], context)
	_check(_signal_emissions == 1, "Test 4 - ResolutionEngine.resolve() after match over did NOT re-emit match_ended")
	_check(GameManager.winner == 0, "Test 4 - Winner remains 0 after subsequent combat resolution")

func _test_both_players_alive_no_winner() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(25)
	var hero1 := _create_hero(20)
	GameManager.setup_match([hero0, hero1], [HumanDecisionSource.new(), DummyAIDecisionSource.new()])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	context.turn_number = 3
	var res: int = GameManager.check_win_condition()

	_check(res == -1, "Test 5 - check_win_condition returns -1 when both players alive and turn limit not reached")
	_check(not GameManager.is_match_over, "Test 5 - GameManager.is_match_over is false")
	_check(GameManager.winner == -1, "Test 5 - GameManager.winner is -1")
	_check(_signal_emissions == 0, "Test 5 - match_ended was NOT emitted (count: %d)" % _signal_emissions)
	_check(not p0.is_eliminated and not p1.is_eliminated, "Test 5 - Neither player is marked eliminated")

func _test_direct_life_reduction_elimination() -> void:
	_reset_signal_tracker()
	var hero0 := _create_hero(25)
	var hero1 := _create_hero(25)
	GameManager.setup_match([hero0, hero1], [HumanDecisionSource.new(), DummyAIDecisionSource.new()])
	var context: MatchContext = GameManager.match_context
	var p0: KingdomState = context.kingdoms[0]
	var p1: KingdomState = context.kingdoms[1]

	# Directly drop p0 life to 0 without running combat
	p0.life = 0
	_check(not p0.is_eliminated, "Test 6 - Before check_win_condition, p0.is_eliminated is false")

	var declared: int = GameManager.check_win_condition()
	_check(p0.is_eliminated, "Test 6 - check_win_condition marked p0.is_eliminated true")
	_check(declared == 1, "Test 6 - check_win_condition declared survivor player 1 as winner")
	_check(GameManager.is_match_over, "Test 6 - GameManager.is_match_over is true")
	_check(GameManager.winner == 1, "Test 6 - GameManager.winner is 1")
	_check(_signal_emissions == 1, "Test 6 - match_ended emitted exactly once for direct elimination")
	_check(_signal_winner == 1, "Test 6 - match_ended emitted winner 1")
