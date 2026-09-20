extends Node

const ComebackConfigResource = preload("res://scripts/data/comeback_config_resource.gd")

var _passed := 0
var _failed := 0
var _manual := 0

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

func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--negative-test" in args:
		_check(false, "Simulated intentional failure for negative testing verification")

	_test_default_config_resource()
	_test_uneven_life_totals()
	_test_tied_for_last()
	_test_all_equal_life()
	_test_eliminated_players_excluded()
	_test_consecutive_rounds_dynamic_adaptation()
	_test_single_active_player()

	_manual_check("Comeback Essence bonus visual banner/cue in MatchBoard HUD")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("ComebackCheck: FAIL")
		get_tree().quit(1)
	else:
		print("ComebackCheck: PASS")
		get_tree().quit(0)

func _test_default_config_resource() -> void:
	var config_path := "res://data/combat/default_comeback_config.tres"
	_check(ResourceLoader.exists(config_path), "ComebackConfig: default_comeback_config.tres exists")

	var cfg: ComebackConfigResource = load(config_path)
	_check(cfg != null, "ComebackConfig: loaded config successfully")
	if cfg != null:
		_check(cfg.bonus_essence == 1, "ComebackConfig: default bonus_essence is 1")
		_check(cfg.tie_mode == ComebackConfigResource.TieMode.ALL_TIED, "ComebackConfig: default tie_mode is ALL_TIED")

func _test_uneven_life_totals() -> void:
	TurnManager.comeback_config = load("res://data/combat/default_comeback_config.tres")

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 0

	var p1 := KingdomState.new(1)
	p1.life = 20
	p1.essence = 0

	var p2 := KingdomState.new(2)
	p2.life = 15
	p2.essence = 0

	ctx.kingdoms.append_array([p0, p1, p2])

	var signal_data := {
		"received": false,
		"recipients": [] as Array[int],
		"amount": 0
	}
	var handler := func(recipients: Array[int], bonus: int) -> void:
		signal_data["received"] = true
		signal_data["recipients"] = recipients.duplicate()
		signal_data["amount"] = bonus

	TurnManager.comeback_bonus_awarded.connect(handler, CONNECT_ONE_SHOT)

	var res := TurnManager.apply_comeback_bonus(ctx)
	_check(res.get("recipient_ids") == [2], "Uneven Life: only P2 is recipient")
	_check(res.get("bonus_essence") == 1, "Uneven Life: bonus amount is 1")
	_check(res.get("min_life") == 15, "Uneven Life: min_life is 15")
	_check(p0.essence == 0, "Uneven Life: P0 gets 0 bonus essence")
	_check(p1.essence == 0, "Uneven Life: P1 gets 0 bonus essence")
	_check(p2.essence == 1, "Uneven Life: P2 receives +1 essence")
	_check(signal_data["received"], "Uneven Life: comeback_bonus_awarded signal emitted")
	_check(signal_data["recipients"] == [2], "Uneven Life: signal recipients matches [2]")
	_check(signal_data["amount"] == 1, "Uneven Life: signal amount is 1")

func _test_tied_for_last() -> void:
	# 1. Test TieMode.ALL_TIED
	var cfg_all := ComebackConfigResource.new()
	cfg_all.bonus_essence = 1
	cfg_all.tie_mode = ComebackConfigResource.TieMode.ALL_TIED
	TurnManager.comeback_config = cfg_all

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 2

	var p1 := KingdomState.new(1)
	p1.life = 15
	p1.essence = 2

	var p2 := KingdomState.new(2)
	p2.life = 15
	p2.essence = 2

	ctx.kingdoms.append_array([p0, p1, p2])

	var res_all := TurnManager.apply_comeback_bonus(ctx)
	_check(res_all.get("recipient_ids") == [1, 2], "Tied Last (ALL_TIED): both P1 and P2 in recipient_ids")
	_check(p0.essence == 2, "Tied Last (ALL_TIED): P0 essence unchanged at 2")
	_check(p1.essence == 3, "Tied Last (ALL_TIED): P1 received exactly +1 essence (not duplicate +2)")
	_check(p2.essence == 3, "Tied Last (ALL_TIED): P2 received exactly +1 essence (not duplicate +2)")

	# 2. Test TieMode.LOWEST_ID
	var cfg_lowest := ComebackConfigResource.new()
	cfg_lowest.bonus_essence = 1
	cfg_lowest.tie_mode = ComebackConfigResource.TieMode.LOWEST_ID
	TurnManager.comeback_config = cfg_lowest

	p0.essence = 0
	p1.essence = 0
	p2.essence = 0

	var res_lowest := TurnManager.apply_comeback_bonus(ctx)
	_check(res_lowest.get("recipient_ids") == [1], "Tied Last (LOWEST_ID): only lowest ID P1 is recipient")
	_check(p0.essence == 0, "Tied Last (LOWEST_ID): P0 essence 0")
	_check(p1.essence == 1, "Tied Last (LOWEST_ID): P1 essence +1")
	_check(p2.essence == 0, "Tied Last (LOWEST_ID): P2 essence 0")

	# 3. Test TieMode.NONE
	var cfg_none := ComebackConfigResource.new()
	cfg_none.bonus_essence = 1
	cfg_none.tie_mode = ComebackConfigResource.TieMode.NONE
	TurnManager.comeback_config = cfg_none

	p0.essence = 0
	p1.essence = 0
	p2.essence = 0

	var res_none := TurnManager.apply_comeback_bonus(ctx)
	_check(res_none.get("recipient_ids").is_empty(), "Tied Last (NONE): recipient_ids is empty")
	_check(p0.essence == 0 and p1.essence == 0 and p2.essence == 0, "Tied Last (NONE): no player essence incremented")

func _test_all_equal_life() -> void:
	TurnManager.comeback_config = load("res://data/combat/default_comeback_config.tres")

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 1

	var p1 := KingdomState.new(1)
	p1.life = 25
	p1.essence = 1

	var p2 := KingdomState.new(2)
	p2.life = 25
	p2.essence = 1

	ctx.kingdoms.append_array([p0, p1, p2])

	var res := TurnManager.apply_comeback_bonus(ctx)
	_check(res.get("recipient_ids").is_empty(), "Equal Life: recipient_ids is empty")
	_check(res.get("bonus_essence") == 0, "Equal Life: bonus_essence is 0")
	_check(p0.essence == 1 and p1.essence == 1 and p2.essence == 1, "Equal Life: no player received bonus essence")

func _test_eliminated_players_excluded() -> void:
	TurnManager.comeback_config = load("res://data/combat/default_comeback_config.tres")

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 0

	var p1 := KingdomState.new(1)
	p1.life = 18
	p1.essence = 0

	var p2 := KingdomState.new(2)
	p2.life = 0
	p2.is_eliminated = true
	p2.essence = 0

	ctx.kingdoms.append_array([p0, p1, p2])

	var res := TurnManager.apply_comeback_bonus(ctx)
	_check(res.get("recipient_ids") == [1], "Eliminated: P2 (0 life / eliminated) excluded, lowest active is P1")
	_check(p1.essence == 1, "Eliminated: active lowest P1 received +1 essence")
	_check(p2.essence == 0, "Eliminated: eliminated P2 received 0 essence")

func _test_consecutive_rounds_dynamic_adaptation() -> void:
	TurnManager.comeback_config = load("res://data/combat/default_comeback_config.tres")

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 20
	p0.essence = 0

	var p1 := KingdomState.new(1)
	p1.life = 15
	p1.essence = 0

	ctx.kingdoms.append_array([p0, p1])

	# Round 1: P1 is lowest (15 vs 20)
	var r1 := TurnManager.apply_comeback_bonus(ctx)
	_check(r1.get("recipient_ids") == [1], "Round 1: P1 lowest, receives bonus")
	_check(p1.essence == 1, "Round 1: P1 essence is 1")
	_check(p0.essence == 0, "Round 1: P0 essence is 0")

	# Life totals swing: P0 takes heavy damage, life becomes 10 (P1 remains 15)
	p0.life = 10
	# Round 2: P0 is now lowest (10 vs 15)
	var r2 := TurnManager.apply_comeback_bonus(ctx)
	_check(r2.get("recipient_ids") == [0], "Round 2: P0 lowest after damage swing, receives bonus")
	_check(p0.essence == 1, "Round 2: P0 essence is 1")
	_check(p1.essence == 1, "Round 2: P1 essence remains 1")

func _test_single_active_player() -> void:
	TurnManager.comeback_config = load("res://data/combat/default_comeback_config.tres")

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 20
	p0.essence = 0

	ctx.kingdoms.append(p0)

	var res := TurnManager.apply_comeback_bonus(ctx)
	_check(res.get("recipient_ids").is_empty(), "Single player: recipient_ids is empty")
	_check(p0.essence == 0, "Single player: P0 essence remains 0")
