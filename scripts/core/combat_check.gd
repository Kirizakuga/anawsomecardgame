extends Node

func _ready() -> void:
	_test_combat_resolution_cases_a_b_c()
	_test_combat_resolution_case_d_empty_lanes()
	_test_resolution_engine_integration()
	_test_card_database_creatures()
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

	assert(attacker.life == 25, "Attacker should start at 25 life")
	assert(defender.life == 25, "Defender should start at 25 life")

	var log_entries: Array[Dictionary] = CombatResolver.resolve_combat(attacker, defender)
	assert(log_entries.size() == 3, "Log should have 3 entries (one per lane)")

	# Assert Case a: Lane 0
	assert(log_entries[0]["outcome"] == "blocked_destroyed", "Lane 0 outcome must be blocked_destroyed")
	assert(log_entries[0]["net_damage"] == 1, "Lane 0 net damage should be 3 - 2 = 1")
	assert(log_entries[0]["life_damage"] == 0, "Lane 0 blocked attack must deal 0 life damage")
	assert(log_entries[0]["blocker_destroyed"] == true, "Lane 0 blocker must be destroyed")
	assert(defender.lanes[0].is_empty(), "Defender lane 0 must be empty after blocker destroyed")
	assert(defender.discard.has(creature_a_def), "Destroyed blocker must be added to defender discard pile")
	assert(attacker.lanes[0].size() == 1 and attacker.lanes[0][0] == creature_a_atk, "Attacker creature 0 must survive")
	print("[CHECK] PASS: Case a - Blocked lane destroyed (ATK 3 vs DEF 2, net=1>0, no life damage)")

	# Assert Case b: Lane 1
	assert(log_entries[1]["outcome"] == "blocked_survived", "Lane 1 outcome must be blocked_survived")
	assert(log_entries[1]["net_damage"] == 0, "Lane 1 net damage should be max(0, 2 - 3) = 0")
	assert(log_entries[1]["life_damage"] == 0, "Lane 1 blocked attack must deal 0 life damage")
	assert(log_entries[1]["blocker_destroyed"] == false, "Lane 1 blocker must survive")
	assert(defender.lanes[1].size() == 1 and defender.lanes[1][0] == creature_b_def, "Defender blocker 1 must remain in lane")
	assert(attacker.lanes[1].size() == 1 and attacker.lanes[1][0] == creature_b_atk, "Attacker creature 1 must survive")
	print("[CHECK] PASS: Case b - Blocked lane survived (ATK 2 vs DEF 3, net=0, no life damage)")

	# Assert Case c: Lane 2
	assert(log_entries[2]["outcome"] == "unblocked_damage", "Lane 2 outcome must be unblocked_damage")
	assert(log_entries[2]["damage"] == 4, "Lane 2 damage should equal attacker ATK 4")
	assert(log_entries[2]["life_damage"] == 4, "Lane 2 life damage should be 4")
	assert(defender.lanes[2].is_empty(), "Defender lane 2 remains empty")
	assert(attacker.lanes[2].size() == 1 and attacker.lanes[2][0] == creature_c_atk, "Attacker creature 2 must survive")
	print("[CHECK] PASS: Case c - Unblocked lane direct damage (ATK 4, Life 25 -> 21)")

	# Assert Kingdom Life totals
	assert(defender.life == 21, "Defender life must be exactly 25 - 4 = 21, got %d" % defender.life)
	assert(attacker.life == 25, "Attacker life must be unchanged (no retaliation), got %d" % attacker.life)
	print("[CHECK] PASS: Exact Life totals after combat match expected (25 attacker, 21 defender)")


func _test_combat_resolution_case_d_empty_lanes() -> void:
	# Case d: Empty lane vs empty lane: nothing happens
	var attacker := KingdomState.new(0)
	var defender := KingdomState.new(1)

	var log_entries: Array[Dictionary] = CombatResolver.resolve_combat(attacker, defender)
	assert(log_entries.size() == 3, "Empty lanes should produce 3 log entries")
	for i in range(3):
		assert(log_entries[i]["outcome"] == "empty", "Lane %d outcome must be empty" % i)
		assert(log_entries[i]["damage"] == 0, "Lane %d damage must be 0" % i)
		assert(log_entries[i]["life_damage"] == 0, "Lane %d life damage must be 0" % i)

	assert(attacker.life == 25, "Attacker life unchanged on empty combat")
	assert(defender.life == 25, "Defender life unchanged on empty combat")
	print("[CHECK] PASS: Case d - Empty lane vs empty lane no-op")


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
	assert(p0.life == 23, "P0 life should be 23 after unblocked hit from P1, got %d" % p0.life)
	assert(p1.life == 22, "P1 life should be 22 after unblocked hit from P0, got %d" % p1.life)
	assert(res_log.size() == 6, "2 players * 3 lanes = 6 resolution log entries")
	print("[CHECK] PASS: ResolutionEngine.resolve() 2-player combat step integration")


func _test_card_database_creatures() -> void:
	if CardDatabase == null:
		return

	# Load real .tres cards
	var drake := CardDatabase.get_card("cr_flame_drake") as CreatureResource  # ATK 4, DEF 2
	var golem := CardDatabase.get_card("cr_stone_golem") as CreatureResource  # ATK 2, DEF 4
	var treant := CardDatabase.get_card("cr_ancient_treant") as CreatureResource # ATK 5, DEF 6

	assert(drake != null and golem != null and treant != null, "CardDatabase must provide test creatures")

	var k1 := KingdomState.new(0)
	var k2 := KingdomState.new(1)

	# Lane 0: Drake (ATK 4) attacks Golem (DEF 4) -> net = 4 - 4 = 0 -> Golem survives
	k1.lanes[0].append(drake)
	k2.lanes[0].append(golem)

	# Lane 1: Treant (ATK 5) attacks Drake (DEF 2) -> net = 5 - 2 = 3 -> Drake destroyed
	k1.lanes[1].append(treant)
	k2.lanes[1].append(drake)

	var log: Array[Dictionary] = CombatResolver.resolve_combat(k1, k2)
	assert(log[0]["outcome"] == "blocked_survived", "Golem DEF 4 blocks Drake ATK 4")
	assert(k2.lanes[0].size() == 1 and k2.lanes[0][0] == golem, "Golem should survive")

	assert(log[1]["outcome"] == "blocked_destroyed", "Treant ATK 5 destroys Drake DEF 2")
	assert(k2.lanes[1].is_empty(), "Drake should be destroyed and removed from lane")
	assert(k2.discard.has(drake), "Destroyed Drake should be in discard")

	print("[CHECK] PASS: Real CardDatabase .tres cards combat math verified")
