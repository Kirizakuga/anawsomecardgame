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
	_test_combat_resolution_cases_a_b_c()
	_test_combat_resolution_case_d_empty_lanes()
	_test_resolution_engine_integration()
	_test_card_database_creatures()
	print("[CHECK] SUMMARY: %d passed, %d failed, 0 manual" % [_passed, _failed])
	if _failed > 0:
		print("CombatCheck: FAIL")
		get_tree().quit(1)
	else:
		print("CombatCheck: PASS")
		get_tree().quit()


func _test_combat_resolution_cases_a_b_c() -> void:
	var attacker := KingdomState.new(0)
	var defender := KingdomState.new(1)

	# Case a: Lane 0 - ATK 3 vs DEF 2 -> blocker destroyed (net=1>0), no life damage
	var creature_a_atk := CreatureResource.new()
	creature_a_atk.id = "test_atk_3"
	creature_a_atk.attack = 3
	creature_a_atk.defense = 1

	var creature_a_def := CreatureResource.new()
	creature_a_def.id = "test_def_2"
	creature_a_def.attack = 1
	creature_a_def.defense = 2

	attacker.lanes[0].append(creature_a_atk)
	defender.lanes[0].append(creature_a_def)

	# Case b: Lane 1 - ATK 2 vs DEF 3 -> blocker survives (net=0), no life damage
	var creature_b_atk := CreatureResource.new()
	creature_b_atk.id = "test_atk_2"
	creature_b_atk.attack = 2
	creature_b_atk.defense = 1

	var creature_b_def := CreatureResource.new()
	creature_b_def.id = "test_def_3"
	creature_b_def.attack = 1
	creature_b_def.defense = 3

	attacker.lanes[1].append(creature_b_atk)
	defender.lanes[1].append(creature_b_def)

	# Case c: Lane 2 - ATK 4, empty opposing lane -> defender Kingdom Life -= 4
	var creature_c_atk := CreatureResource.new()
	creature_c_atk.id = "test_atk_4"
	creature_c_atk.attack = 4
	creature_c_atk.defense = 2

	attacker.lanes[2].append(creature_c_atk)
	# defender.lanes[2] left empty

	_check(attacker.life == 25 and defender.life == 25, "Initial Life totals: attacker 25, defender 25")

	var log_entries: Array[Dictionary] = CombatResolver.resolve_combat(attacker, defender)
	_check(log_entries.size() == 3, "Combat resolution returns 3 lane log entries")

	# Assert Case a: Lane 0
	var case_a_pass: bool = (
		log_entries.size() > 0
		and log_entries[0].get("outcome") == "blocked_destroyed"
		and log_entries[0].get("net_damage") == 1
		and log_entries[0].get("life_damage") == 0
		and log_entries[0].get("blocker_destroyed") == true
		and defender.lanes[0].is_empty()
		and defender.discard.has(creature_a_def)
		and attacker.lanes[0].size() == 1
		and attacker.lanes[0][0] == creature_a_atk
	)
	_check(case_a_pass, "Case a - Blocked lane destroyed (ATK 3 vs DEF 2, net=1>0, no life damage)")

	# Assert Case b: Lane 1
	var case_b_pass: bool = (
		log_entries.size() > 1
		and log_entries[1].get("outcome") == "blocked_survived"
		and log_entries[1].get("net_damage") == 0
		and log_entries[1].get("life_damage") == 0
		and log_entries[1].get("blocker_destroyed") == false
		and defender.lanes[1].size() == 1
		and defender.lanes[1][0] == creature_b_def
		and attacker.lanes[1].size() == 1
		and attacker.lanes[1][0] == creature_b_atk
	)
	_check(case_b_pass, "Case b - Blocked lane survived (ATK 2 vs DEF 3, net=0, no life damage)")

	# Assert Case c: Lane 2
	var case_c_pass: bool = (
		log_entries.size() > 2
		and log_entries[2].get("outcome") == "unblocked_damage"
		and log_entries[2].get("damage") == 4
		and log_entries[2].get("life_damage") == 4
		and defender.lanes[2].is_empty()
		and attacker.lanes[2].size() == 1
		and attacker.lanes[2][0] == creature_c_atk
	)
	_check(case_c_pass, "Case c - Unblocked lane direct damage (ATK 4, Life 25 -> 21)")

	# Assert Kingdom Life totals
	var life_pass: bool = (defender.life == 21 and attacker.life == 25)
	_check(life_pass, "Exact Life totals after combat match expected (25 attacker, 21 defender)")


func _test_combat_resolution_case_d_empty_lanes() -> void:
	# Case d: Empty lane vs empty lane: nothing happens
	var attacker := KingdomState.new(0)
	var defender := KingdomState.new(1)

	var log_entries: Array[Dictionary] = CombatResolver.resolve_combat(attacker, defender)
	var case_d_pass: bool = (
		log_entries.size() == 3
		and attacker.life == 25
		and defender.life == 25
	)
	if case_d_pass:
		for i in range(3):
			if log_entries[i].get("outcome") != "empty" or log_entries[i].get("damage") != 0 or log_entries[i].get("life_damage") != 0:
				case_d_pass = false
				break
	_check(case_d_pass, "Case d - Empty lane vs empty lane no-op")


func _test_resolution_engine_integration() -> void:
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)

	# Give p0 a creature in lane 0 (ATK 3, DEF 1)
	var c0 := CreatureResource.new()
	c0.id = "p0_creature"
	c0.attack = 3
	c0.defense = 1
	p0.lanes[0].append(c0)

	# Give p1 a creature in lane 1 (ATK 2, DEF 2)
	var c1 := CreatureResource.new()
	c1.id = "p1_creature"
	c1.attack = 2
	c1.defense = 2
	p1.lanes[1].append(c1)

	var context := MatchContext.new()
	context.kingdoms = [p0, p1]

	var all_actions: Array[RoundActions] = []
	var res_log: Array = ResolutionEngine.resolve(all_actions, context)

	# P0 attacks P1:
	# Lane 0: P0 ATK 3 unblocked -> P1 life -= 3 (25 -> 22)
	# Lane 1: P0 empty -> nothing
	# Lane 2: P0 empty -> nothing
	# P1 attacks P0:
	# Lane 0: P1 empty -> nothing
	# Lane 1: P1 ATK 2 unblocked -> P0 life -= 2 (25 -> 23)
	# Lane 2: P1 empty -> nothing
	var integration_pass: bool = (
		p0.life == 23
		and p1.life == 22
		and res_log.size() == 6
	)
	_check(integration_pass, "ResolutionEngine.resolve() 2-player combat step integration")


func _test_card_database_creatures() -> void:
	if CardDatabase == null:
		_check(false, "CardDatabase autoload available")
		return

	# Load real .tres cards
	var drake := CardDatabase.get_card("cr_flame_drake") as CreatureResource  # ATK 4, DEF 2
	var golem := CardDatabase.get_card("cr_stone_golem") as CreatureResource  # ATK 2, DEF 4
	var treant := CardDatabase.get_card("cr_ancient_treant") as CreatureResource # ATK 5, DEF 6

	var cards_loaded: bool = (drake != null and golem != null and treant != null)
	_check(cards_loaded, "CardDatabase test creatures loaded (drake, golem, treant)")
	if not cards_loaded:
		return

	var k1 := KingdomState.new(0)
	var k2 := KingdomState.new(1)

	# Lane 0: Drake (ATK 4) attacks Golem (DEF 4) -> net = 4 - 4 = 0 -> Golem survives
	k1.lanes[0].append(drake)
	k2.lanes[0].append(golem)

	# Lane 1: Treant (ATK 5) attacks Drake (DEF 2) -> net = 5 - 2 = 3 -> Drake destroyed
	k1.lanes[1].append(treant)
	k2.lanes[1].append(drake)

	var log: Array[Dictionary] = CombatResolver.resolve_combat(k1, k2)
	var math_pass: bool = (
		log.size() >= 2
		and log[0].get("outcome") == "blocked_survived"
		and k2.lanes[0].size() == 1
		and k2.lanes[0][0] == golem
		and log[1].get("outcome") == "blocked_destroyed"
		and k2.lanes[1].is_empty()
		and k2.discard.has(drake)
	)
	_check(math_pass, "Real CardDatabase .tres cards combat math verified")
