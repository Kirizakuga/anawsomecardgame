extends Node

const BetrayalConfigResource = preload("res://scripts/data/betrayal_config_resource.gd")

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

	_test_default_betrayal_config()
	_test_human_decision_source_targeting()
	_test_same_turn_break_and_attack()
	_test_break_pact_without_attack()
	_test_multi_lane_attack_single_essence_bonus()

	_manual_check("Betrayal visual feedback and animation cues in MatchBoard")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("BetrayalCheck: FAIL")
		get_tree().quit(1)
	else:
		print("BetrayalCheck: PASS")
		get_tree().quit(0)

func _test_default_betrayal_config() -> void:
	var config_path := "res://data/pact/default_betrayal_config.tres"
	_check(ResourceLoader.exists(config_path), "BetrayalConfig: default_betrayal_config.tres exists")

	var cfg: BetrayalConfigResource = load(config_path)
	_check(cfg != null, "BetrayalConfig: loaded config successfully")
	if cfg != null:
		_check(cfg.bonus_essence == 2, "BetrayalConfig: default bonus_essence is 2")
		_check(cfg.bonus_attack_damage == 2, "BetrayalConfig: default bonus_attack_damage is 2")

func _test_human_decision_source_targeting() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	var p2 := KingdomState.new(2)
	ctx.kingdoms.append_array([p0, p1, p2])

	PactManager.accept_pact(0, 1)
	_check(PactManager.has_pact(0, 1), "Targeting: P0 and P1 have active pact")

	var source := HumanDecisionSource.new()
	source.request_actions(p0, ctx)
	source.target_validator = func(from_id: int, to_id: int) -> bool:
		return PactManager.can_attack(from_id, to_id)

	# 1. Without betrayal declared: targeting ally is blocked
	_check(not source.can_target_for_attack(1), "Targeting: can_target_for_attack(1) returns false when no betrayal declared")
	var queued_no_betrayal := source.queue_attack_target(0, 1, 0)
	_check(not queued_no_betrayal, "Targeting: queue_attack_target to ally returns false when no betrayal declared")
	_check(source.pending_actions.attack_targets.is_empty(), "Targeting: attack_targets remains empty")

	# Targeting neutral opponent is allowed
	_check(source.can_target_for_attack(2), "Targeting: can_target_for_attack(2) returns true for neutral opponent")

	# 2. With betrayal declared: targeting ally is permitted
	source.queue_betrayal(1)
	_check(source.pending_actions.betrayal_target == 1, "Targeting: betrayal_target set to 1 in pending_actions")
	_check(source.can_target_for_attack(1), "Targeting: can_target_for_attack(1) returns true after declaring betrayal against ally")
	var queued_with_betrayal := source.queue_attack_target(0, 1, 0)
	_check(queued_with_betrayal, "Targeting: queue_attack_target to ally returns true after declaring betrayal")
	_check(source.pending_actions.attack_targets.size() == 1, "Targeting: ally attack successfully queued in attack_targets")

func _test_same_turn_break_and_attack() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 3

	var p1 := KingdomState.new(1)
	p1.life = 25
	p1.essence = 3

	var p2 := KingdomState.new(2)
	p2.life = 25
	p2.essence = 3

	ctx.kingdoms.append_array([p0, p1, p2])

	# Form pact between P0 and P1
	PactManager.accept_pact(0, 1)
	_check(PactManager.has_pact(0, 1), "SameTurn: Pact formed between P0 and P1")

	# Place creature with ATK 2 in P0 lane 0; P1 lane 0 is unblocked
	var golem := CreatureResource.new()
	golem.id = "test_golem"
	golem.attack = 2
	golem.defense = 3
	p0.lanes[0].append(golem)

	# P0 declares betrayal against P1 AND attacks P1 lane 0
	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.betrayal_target = 1
	act0.attack_targets.append({"attacker_lane": 0, "target_player_id": 1, "target_lane": 0})

	var act1 := RoundActions.new()
	act1.player_id = 1

	var act2 := RoundActions.new()
	act2.player_id = 2

	var log: Array = ResolutionEngine.resolve([act0, act1, act2], ctx)

	# Combat verification: ATK 2 + bonus 2 = 4 total damage, penetrating pact
	# P1 life was 25 -> should be 21
	_check(p1.life == 21, "SameTurn: Attack penetrated pact and dealt damage with bonus (25 - 4 = 21, actual: %d)" % p1.life)

	# Check combat log entry details
	var combat_entry: Dictionary = {}
	for entry in log:
		if entry is Dictionary and entry.get("attacker_id") == 0 and entry.get("defender_id") == 1:
			combat_entry = entry
			break
	_check(not combat_entry.is_empty(), "SameTurn: Combat entry between P0 and P1 found in log")
	_check(combat_entry.get("bonus_attack") == 2, "SameTurn: Combat entry recorded bonus_attack of 2")
	_check(combat_entry.get("damage") == 4, "SameTurn: Combat entry recorded total damage of 4")

	# Pact verification: pact must be broken
	_check(not PactManager.has_pact(0, 1), "SameTurn: Pact between P0 and P1 is broken")
	_check(not PactManager.has_pact(1, 0), "SameTurn: Bilateral pact check confirms broken")

	# Essence verification: P0 receives bonus_essence (2) exactly once: 3 + 2 = 5
	_check(p0.essence == 5, "SameTurn: Betrayer P0 received essence bonus exactly once (3 + 2 = 5, actual: %d)" % p0.essence)

	# Resolution log verification
	var betrayal_entries: Array = []
	for entry in log:
		if entry is Dictionary and entry.get("step") == "betrayal" and entry.get("player_id") == 0:
			betrayal_entries.append(entry)
	_check(betrayal_entries.size() == 1, "SameTurn: Exactly one betrayal log entry recorded for P0")
	if betrayal_entries.size() == 1:
		var b_entry: Dictionary = betrayal_entries[0]
		_check(b_entry.get("target_player_id") == 1, "SameTurn: Betrayal target_player_id is 1")
		_check(b_entry.get("bonus_granted") == true, "SameTurn: Betrayal entry has bonus_granted == true")

func _test_break_pact_without_attack() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 3

	var p1 := KingdomState.new(1)
	p1.life = 25
	p1.essence = 3

	var p2 := KingdomState.new(2)
	p2.life = 25
	p2.essence = 3

	ctx.kingdoms.append_array([p0, p1, p2])

	PactManager.accept_pact(0, 1)
	_check(PactManager.has_pact(0, 1), "NoAttack: Pact formed between P0 and P1")

	# Place creature in P0 lane 0, but attack neutral P2 instead of allied P1
	var golem := CreatureResource.new()
	golem.id = "test_golem"
	golem.attack = 2
	golem.defense = 3
	p0.lanes[0].append(golem)

	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.betrayal_target = 1 # declared betrayal against P1
	act0.attack_targets.append({"attacker_lane": 0, "target_player_id": 2, "target_lane": 0}) # attacked P2!

	var act1 := RoundActions.new()
	act1.player_id = 1

	var act2 := RoundActions.new()
	act2.player_id = 2

	var log: Array = ResolutionEngine.resolve([act0, act1, act2], ctx)

	# Pact is broken
	_check(not PactManager.has_pact(0, 1), "NoAttack: Pact between P0 and P1 is broken")

	# P1 took 0 damage
	_check(p1.life == 25, "NoAttack: Former ally P1 life remains 25 (untouched)")

	# P0 receives 0 bonus essence: essence remains 3
	_check(p0.essence == 3, "NoAttack: Breaker P0 receives 0 bonus essence (essence remains 3, actual: %d)" % p0.essence)

	# Resolution log verification
	var betrayal_entries: Array = []
	for entry in log:
		if entry is Dictionary and entry.get("step") == "betrayal" and entry.get("player_id") == 0:
			betrayal_entries.append(entry)
	_check(betrayal_entries.size() == 1, "NoAttack: Exactly one betrayal log entry recorded for P0")
	if betrayal_entries.size() == 1:
		var b_entry: Dictionary = betrayal_entries[0]
		_check(b_entry.get("target_player_id") == 1, "NoAttack: Betrayal target_player_id is 1")
		_check(b_entry.get("bonus_granted") == false, "NoAttack: Betrayal entry has bonus_granted == false")

func _test_multi_lane_attack_single_essence_bonus() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	p0.life = 25
	p0.essence = 4

	var p1 := KingdomState.new(1)
	p1.life = 25
	p1.essence = 3

	ctx.kingdoms.append_array([p0, p1])

	PactManager.accept_pact(0, 1)

	# Place creatures in lane 0 and lane 1 for P0
	var c0 := CreatureResource.new()
	c0.id = "c0"
	c0.attack = 1
	c0.defense = 1
	p0.lanes[0].append(c0)

	var c1 := CreatureResource.new()
	c1.id = "c1"
	c1.attack = 1
	c1.defense = 1
	p0.lanes[1].append(c1)

	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.betrayal_target = 1
	act0.attack_targets.append({"attacker_lane": 0, "target_player_id": 1, "target_lane": 0})
	act0.attack_targets.append({"attacker_lane": 1, "target_player_id": 1, "target_lane": 1})

	var act1 := RoundActions.new()
	act1.player_id = 1

	var log: Array = ResolutionEngine.resolve([act0, act1], ctx)

	# Both lane attacks penetrate and deal (1 + 2) = 3 damage each, total 6
	_check(p1.life == 19, "MultiLane: Both attacks dealt damage with bonus (25 - 6 = 19, actual: %d)" % p1.life)

	# Essence burst is granted exactly once: 4 + 2 = 6 (NOT 4 + 2 + 2 = 8)
	_check(p0.essence == 6, "MultiLane: Essence burst granted exactly once across multi-lane attack (4 + 2 = 6, actual: %d)" % p0.essence)
