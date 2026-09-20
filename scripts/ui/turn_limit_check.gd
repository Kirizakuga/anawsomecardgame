extends Node

const WinConditionConfigResource = preload("res://scripts/data/win_condition_config_resource.gd")

var _passed := 0
var _failed := 0
var _manual := 0

var _signal_emissions := 0
var _signal_winner := -999

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CHECK] PASS: %s" % label)
	else:
		_failed += 1
		print("[CHECK] FAIL: %s" % label)

func _manual_check(label: String) -> void:
	_manual += 1
	print("[CHECK] MANUAL: %s" % label)

func _on_match_ended(winner_id: int) -> void:
	_signal_emissions += 1
	_signal_winner = winner_id

func _reset_tracker() -> void:
	_signal_emissions = 0
	_signal_winner = -999
	GameManager.reset_match()
	var default_cfg: WinConditionConfigResource = load("res://data/match/default_win_condition_config.tres")
	GameManager.win_condition_config = default_cfg

func _create_hero(starting_life: int) -> HeroResource:
	var hero := HeroResource.new()
	hero.starting_life = starting_life
	return hero

func _setup_test_match(lives: Array[int], essences: Array[int] = []) -> MatchContext:
	var heroes: Array[HeroResource] = []
	var sources: Array[DecisionSource] = []
	for life in lives:
		heroes.append(_create_hero(life))
		sources.append(DummyAIDecisionSource.new())
	GameManager.setup_match(heroes, sources)
	var ctx := GameManager.match_context
	for i in range(lives.size()):
		ctx.kingdoms[i].life = lives[i]
		if i < essences.size():
			ctx.kingdoms[i].essence = essences[i]
	return ctx

func _ready() -> void:
	GameManager.match_ended.connect(_on_match_ended)

	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--negative-test" in args:
		_check(false, "Simulated intentional failure for negative testing verification")

	_test_default_config_loading()
	_test_two_player_forced_turn_limit()
	_test_four_player_ffa_highest_life()
	_test_five_player_ffa_tie_draw()
	_test_tie_rule_most_essence()
	_test_last_standing_precedence()
	_test_eliminated_player_exclusion()
	_test_turn_manager_integration()

	_manual_check("End-of-match victory banner/screen displaying winner or draw at turn limit")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("TurnLimitCheck: FAIL")
		get_tree().quit(1)
	else:
		print("TurnLimitCheck: PASS")
		get_tree().quit(0)

func _test_default_config_loading() -> void:
	_reset_tracker()
	var config_path := "res://data/match/default_win_condition_config.tres"
	_check(ResourceLoader.exists(config_path), "Default config: default_win_condition_config.tres exists on disk")

	var cfg: WinConditionConfigResource = load(config_path)
	_check(cfg != null, "Default config: loaded WinConditionConfigResource successfully")
	if cfg != null:
		_check(cfg.turn_limit == 30, "Default config: turn_limit is 30")
		_check(cfg.tie_rule == WinConditionConfigResource.TieRule.DRAW, "Default config: tie_rule is DRAW")

	GameManager._ensure_win_condition_config()
	_check(GameManager.win_condition_config != null, "GameManager: win_condition_config loaded")
	if GameManager.win_condition_config != null:
		_check(GameManager.win_condition_config.turn_limit == 30, "GameManager: config turn_limit matches 30")

func _test_two_player_forced_turn_limit() -> void:
	_reset_tracker()
	var ctx := _setup_test_match([18, 22])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == 1, "2-Player turn limit: Player 1 wins with higher Life (22 > 18)")
	_check(GameManager.is_match_over, "2-Player turn limit: match is marked over")
	_check(GameManager.winner == 1, "2-Player turn limit: GameManager.winner is 1")
	_check(_signal_emissions == 1, "2-Player turn limit: match_ended emitted exactly once")
	_check(_signal_winner == 1, "2-Player turn limit: match_ended emitted winner 1")

func _test_four_player_ffa_highest_life() -> void:
	_reset_tracker()
	var ctx := _setup_test_match([25, 20, 15, 10])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == 0, "4-Player FFA turn limit: Player 0 wins with highest Life (25)")
	_check(GameManager.is_match_over, "4-Player FFA turn limit: match is marked over")
	_check(GameManager.winner == 0, "4-Player FFA turn limit: GameManager.winner is 0")
	_check(_signal_emissions == 1, "4-Player FFA turn limit: match_ended emitted exactly once")
	_check(_signal_winner == 0, "4-Player FFA turn limit: match_ended emitted winner 0")

func _test_five_player_ffa_tie_draw() -> void:
	_reset_tracker()
	var ctx := _setup_test_match([25, 25, 20, 15, 10])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == -1, "5-Player FFA tie under DRAW: resolves to draw (-1)")
	_check(GameManager.is_match_over, "5-Player FFA tie: match is marked over")
	_check(GameManager.winner == -1, "5-Player FFA tie: GameManager.winner is -1")
	_check(_signal_emissions == 1, "5-Player FFA tie: match_ended emitted exactly once")
	_check(_signal_winner == -1, "5-Player FFA tie: match_ended emitted winner -1")

func _test_tie_rule_most_essence() -> void:
	# Subtest A: Unique highest essence among tied highest-life players wins
	_reset_tracker()
	var essence_cfg := WinConditionConfigResource.new()
	essence_cfg.turn_limit = 30
	essence_cfg.tie_rule = WinConditionConfigResource.TieRule.MOST_ESSENCE
	GameManager.win_condition_config = essence_cfg

	# P0 life 20 essence 2; P1 life 20 essence 5; P2 life 15 essence 10
	var ctx := _setup_test_match([20, 20, 15], [2, 5, 10])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == 1, "Tie MOST_ESSENCE: P1 wins with higher essence (5 > 2) despite P2 having 10 essence")
	_check(GameManager.is_match_over, "Tie MOST_ESSENCE: match is marked over")
	_check(GameManager.winner == 1, "Tie MOST_ESSENCE: GameManager.winner is 1")
	_check(_signal_emissions == 1, "Tie MOST_ESSENCE: match_ended emitted exactly once")
	_check(_signal_winner == 1, "Tie MOST_ESSENCE: match_ended emitted winner 1")

	# Subtest B: Essence tie among tied highest-life players resolves to draw (-1)
	_reset_tracker()
	GameManager.win_condition_config = essence_cfg
	# P0 life 20 essence 4; P1 life 20 essence 4; P2 life 10 essence 2
	var ctx_tie := _setup_test_match([20, 20, 10], [4, 4, 2])
	ctx_tie.turn_number = ctx_tie.turn_limit

	var tie_winner := GameManager.check_win_condition()
	_check(tie_winner == -1, "Tie MOST_ESSENCE with equal essence: resolves to draw (-1)")
	_check(GameManager.is_match_over, "Tie MOST_ESSENCE with equal essence: match marked over")
	_check(GameManager.winner == -1, "Tie MOST_ESSENCE with equal essence: GameManager.winner is -1")
	_check(_signal_emissions == 1, "Tie MOST_ESSENCE with equal essence: match_ended emitted once")
	_check(_signal_winner == -1, "Tie MOST_ESSENCE with equal essence: match_ended emitted -1")

func _test_last_standing_precedence() -> void:
	# Subtest A: Turn limit reached, but only 1 player alive -> survivor wins immediately
	_reset_tracker()
	var ctx := _setup_test_match([0, 5, 0, 0])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == 1, "Last-standing precedence at turn limit: sole survivor P1 wins immediately")
	_check(GameManager.is_match_over, "Last-standing: match marked over")
	_check(GameManager.winner == 1, "Last-standing: GameManager.winner is 1")
	_check(_signal_emissions == 1, "Last-standing: match_ended emitted once")

	# Subtest B: Before turn limit reached, only 1 player alive -> survivor wins immediately
	_reset_tracker()
	var ctx_mid := _setup_test_match([10, 0])
	ctx_mid.turn_number = 5
	var mid_winner := GameManager.check_win_condition()
	_check(mid_winner == 0, "Last-standing before turn limit: sole survivor P0 wins immediately at turn 5")
	_check(GameManager.winner == 0, "Last-standing before turn limit: winner is 0")

func _test_eliminated_player_exclusion() -> void:
	_reset_tracker()
	# 3 players: P0 was eliminated (life <= 0), P1 has 15 life, P2 has 12 life
	var ctx := _setup_test_match([0, 15, 12])
	ctx.turn_number = ctx.turn_limit

	var winner_id := GameManager.check_win_condition()
	_check(winner_id == 1, "Eliminated player excluded: P1 wins (15 > 12), eliminated P0 ignored")
	_check(ctx.kingdoms[0].is_eliminated, "Eliminated player excluded: P0 is_eliminated is true")
	_check(not ctx.kingdoms[1].is_eliminated, "Eliminated player excluded: P1 is_eliminated is false")
	_check(not ctx.kingdoms[2].is_eliminated, "Eliminated player excluded: P2 is_eliminated is false")
	_check(GameManager.winner == 1, "Eliminated player excluded: GameManager.winner is 1")

func _test_turn_manager_integration() -> void:
	_reset_tracker()
	TurnManager.current_turn = 0
	var ctx := _setup_test_match([25, 20])
	ctx.turn_limit = 3
	TurnManager.set_active_context(ctx)

	_check(not ctx.is_turn_limit_reached(), "TurnManager integration: turn limit not reached initially (turn 0/3)")

	TurnManager.start_turn()
	_check(TurnManager.current_turn == 1, "TurnManager integration: Turn 1 started")
	_check(ctx.turn_number == 1, "TurnManager integration: context.turn_number updated to 1")
	_check(GameManager.check_win_condition(ctx) == -1, "TurnManager integration: no winner at turn 1")

	TurnManager.start_turn()
	_check(TurnManager.current_turn == 2, "TurnManager integration: Turn 2 started")
	_check(ctx.turn_number == 2, "TurnManager integration: context.turn_number updated to 2")

	TurnManager.start_turn()
	_check(TurnManager.current_turn == 3, "TurnManager integration: Turn 3 started")
	_check(ctx.turn_number == 3, "TurnManager integration: context.turn_number updated to 3")
	_check(ctx.is_turn_limit_reached(), "TurnManager integration: is_turn_limit_reached() is true at turn 3/3")

	var declared_winner := GameManager.check_win_condition(ctx)
	_check(declared_winner == 0, "TurnManager integration: check_win_condition triggers and declares P0 winner (25 > 20)")
	_check(GameManager.is_match_over, "TurnManager integration: match is marked over")
	_check(GameManager.winner == 0, "TurnManager integration: winner is 0")
