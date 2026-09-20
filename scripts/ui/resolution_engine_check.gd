extends Node

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

	_test_pile_on_config_resource()
	_test_resolution_order_5_stages()
	_test_multiplayer_floop_targeting()
	_test_three_bots_pile_on_reduction()
	_test_two_attackers_no_pile_on()
	_test_two_player_backward_compatibility()

	_manual_check("Multiplayer combat animations and resolution log presentation in MatchBoard")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("ResolutionEngineCheck: FAIL")
		get_tree().quit(1)
	else:
		print("ResolutionEngineCheck: PASS")
		get_tree().quit(0)


func _test_pile_on_config_resource() -> void:
	var config: PileOnConfigResource = load("res://data/combat/default_pile_on_config.tres")
	_check(config != null, "PileOnConfig: default_pile_on_config.tres loaded successfully")
	if config == null:
		return

	_check(config.threshold == 3, "PileOnConfig: default threshold is 3")
	_check(config.attacker_multipliers.size() == 4, "PileOnConfig: has 4 multiplier tiers")
	_check(is_equal_approx(config.get_multiplier(0), 1.0), "PileOnConfig: 1st attacker multiplier is 1.0")
	_check(is_equal_approx(config.get_multiplier(1), 0.75), "PileOnConfig: 2nd attacker multiplier is 0.75")
	_check(is_equal_approx(config.get_multiplier(2), 0.50), "PileOnConfig: 3rd attacker multiplier is 0.50")
	_check(is_equal_approx(config.get_multiplier(3), 0.25), "PileOnConfig: 4th attacker multiplier is 0.25")
	_check(is_equal_approx(config.get_multiplier(5), 0.25), "PileOnConfig: clamped 5th+ attacker multiplier is 0.25")


func _test_resolution_order_5_stages() -> void:
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	p0.life = 25
	p1.life = 25
	p0.essence = 5
	p1.essence = 5

	var context := MatchContext.new()
	context.kingdoms = [p0, p1]

	var landscape: LandscapeResource = load("res://data/cards/landscapes/ls_volcanic_ridge.tres")
	var scout: CardResource = load("res://data/cards/creatures/cr_goblin_scout.tres")
	var dummy_card := CardResource.new()
	dummy_card.id = "scout_drawn_card"
	p0.deck.append(dummy_card)

	var golem: CreatureResource = load("res://data/cards/creatures/cr_stone_golem.tres").duplicate()
	p0.hand.append(golem)

	# Action for P0 containing all 5 stages:
	# 1. Landscape
	# 2. Floop (scout draw)
	# 3. Creature play (golem into lane 0) + combat attack
	# 4. Pact proposal
	# 5. Betrayal
	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.landscapes_to_play.append(landscape)
	act0.cards_to_floop.append(scout)
	act0.cards_to_play.append({"card": golem, "lane": 0})
	act0.attack_targets.append({"attacker_lane": 0, "target_player_id": 1, "target_lane": 0})
	act0.pact_proposals.append({"target_player_id": 1, "terms": {}})
	act0.betrayal_target = 1

	var act1 := RoundActions.new()
	act1.player_id = 1

	var log: Array = ResolutionEngine.resolve([act0, act1], context)

	# Verify stage 1: Landscape in p0.landscapes
	_check(p0.landscapes.size() == 1 and p0.landscapes[0] == landscape, "Order 1: Landscape added to kingdom landscapes in Step 1")

	# Verify stage 2: Floop executed (card drawn from deck to hand)
	_check(dummy_card in p0.hand, "Order 2: Scout floop executed in Step 2, drawn card in hand")

	# Verify stage 3a: Creature deployed to lane 0
	_check(not p0.lanes[0].is_empty() and p0.lanes[0][0] == golem, "Order 3a: Golem deployed to lane 0 in Step 3a")

	# Verify stage 3b: Combat resolved with golem dealing unblocked damage to p1
	# Golem has ATK 2 -> P1 life 25 - 2 = 23
	_check(p1.life == 23, "Order 3b: Golem attacked in Step 3b, damaging P1 Life (25 -> 23)")

	# Verify stages in resolution log occur in exact fixed sequence:
	# "landscape" -> "floop" -> "creature_play" -> combat -> "pact_proposal" -> "betrayal"
	var steps: Array[String] = []
	for entry in log:
		if entry.has("step"):
			steps.append(entry.step)
		elif entry.has("outcome"):
			steps.append("combat")

	var expected_order := ["landscape", "floop", "creature_play", "combat", "combat", "combat", "combat", "combat", "combat", "pact_proposal", "betrayal"]
	var order_correct := (
		steps.find("landscape") < steps.find("floop")
		and steps.find("floop") < steps.find("creature_play")
		and steps.find("creature_play") < steps.find("combat")
		and steps.rfind("combat") < steps.find("pact_proposal")
		and steps.find("pact_proposal") < steps.find("betrayal")
	)
	_check(order_correct, "Order: Chronological sequence verifies Landscapes -> Floop -> Deploy -> Combat -> Pact -> Betrayal")


func _test_multiplayer_floop_targeting() -> void:
	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	var p2 := KingdomState.new(2)
	var p3 := KingdomState.new(3)
	for k in [p0, p1, p2, p3]:
		k.life = 25
		ctx.kingdoms.append(k)

	p0.essence = 2
	var drake: CardResource = load("res://data/cards/creatures/cr_flame_drake.tres")

	# P0 explicitly targets P3 with Flame Drake direct damage floop
	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.cards_to_floop.append({"card": drake, "target_player_id": 3})

	ResolutionEngine.resolve([act0], ctx)

	_check(p3.life == 23, "Floop Routing: Explicit target P3 took 2 direct damage (25 -> 23)")
	_check(p1.life == 25, "Floop Routing: Default opponent P1 took NO damage (25)")
	_check(p2.life == 25, "Floop Routing: Bystander P2 took NO damage (25)")
	_check(p0.essence == 0, "Floop Routing: Attacker P0 paid 2 essence")


func _test_three_bots_pile_on_reduction() -> void:
	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0) # Defender
	var p1 := KingdomState.new(1) # Attacker 1 (index 0)
	var p2 := KingdomState.new(2) # Attacker 2 (index 1)
	var p3 := KingdomState.new(3) # Attacker 3 (index 2)

	p0.life = 30
	for k in [p1, p2, p3]:
		k.life = 25
	for k in [p0, p1, p2, p3]:
		ctx.kingdoms.append(k)

	# Each attacker has a creature with ATK 4 targeting P0
	# P1 attacks lane 0, P2 attacks lane 1, P3 attacks lane 2
	var c1 := CreatureResource.new()
	c1.id = "c1"
	c1.attack = 4
	c1.defense = 1
	p1.lanes[0].append(c1)

	var c2 := CreatureResource.new()
	c2.id = "c2"
	c2.attack = 4
	c2.defense = 1
	p2.lanes[1].append(c2)

	var c3 := CreatureResource.new()
	c3.id = "c3"
	c3.attack = 4
	c3.defense = 1
	p3.lanes[2].append(c3)

	var act1 := RoundActions.new()
	act1.player_id = 1
	act1.attack_targets.append({"attacker_lane": 0, "target_player_id": 0, "target_lane": 0})

	var act2 := RoundActions.new()
	act2.player_id = 2
	act2.attack_targets.append({"attacker_lane": 1, "target_player_id": 0, "target_lane": 1})

	var act3 := RoundActions.new()
	act3.player_id = 3
	act3.attack_targets.append({"attacker_lane": 2, "target_player_id": 0, "target_lane": 2})

	# Submit in non-sorted order [act3, act1, act2] to test deterministic sorting
	var log: Array = ResolutionEngine.resolve([act3, act1, act2], ctx)

	# Unique attackers targeting P0 = 3 (threshold = 3) -> reduction active!
	# Deterministic attacker sorting: [P1, P2, P3]
	# P1: index 0 -> mult 1.00 -> effective ATK = round(4 * 1.00) = 4
	# P2: index 1 -> mult 0.75 -> effective ATK = round(4 * 0.75) = 3
	# P3: index 2 -> mult 0.50 -> effective ATK = round(4 * 0.50) = 2
	# Total damage = 4 + 3 + 2 = 9
	# Defender life = 30 - 9 = 21

	var p1_combat: Dictionary = {}
	var p2_combat: Dictionary = {}
	var p3_combat: Dictionary = {}

	for entry in log:
		if entry.get("defender_id") == 0:
			var att_id: int = entry.get("attacker_id", -1)
			if att_id == 1:
				p1_combat = entry
			elif att_id == 2:
				p2_combat = entry
			elif att_id == 3:
				p3_combat = entry

	_check(is_equal_approx(p1_combat.get("multiplier", 0.0), 1.0), "Pile-On 3-attackers: Attacker 1 deals 100% (mult 1.0)")
	_check(p1_combat.get("damage", 0) == 4, "Pile-On 3-attackers: Attacker 1 deals 4 damage")

	_check(is_equal_approx(p2_combat.get("multiplier", 0.0), 0.75), "Pile-On 3-attackers: Attacker 2 deals 75% (mult 0.75)")
	_check(p2_combat.get("damage", 0) == 3, "Pile-On 3-attackers: Attacker 2 deals 3 damage (round(4 * 0.75))")

	_check(is_equal_approx(p3_combat.get("multiplier", 0.0), 0.50), "Pile-On 3-attackers: Attacker 3 deals 50% (mult 0.50)")
	_check(p3_combat.get("damage", 0) == 2, "Pile-On 3-attackers: Attacker 3 deals 2 damage (round(4 * 0.50))")

	_check(p0.life == 21, "Pile-On 3-attackers: Defender P0 final Life is exactly 21 (30 - 9 = 21, not 18)")


func _test_two_attackers_no_pile_on() -> void:
	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0) # Defender
	var p1 := KingdomState.new(1) # Attacker 1
	var p2 := KingdomState.new(2) # Attacker 2
	p0.life = 30
	p1.life = 25
	p2.life = 25
	for k in [p0, p1, p2]:
		ctx.kingdoms.append(k)

	var c1 := CreatureResource.new()
	c1.id = "c1"
	c1.attack = 4
	c1.defense = 1
	p1.lanes[0].append(c1)

	var c2 := CreatureResource.new()
	c2.id = "c2"
	c2.attack = 4
	c2.defense = 1
	p2.lanes[1].append(c2)

	var act1 := RoundActions.new()
	act1.player_id = 1
	act1.attack_targets.append({"attacker_lane": 0, "target_player_id": 0, "target_lane": 0})

	var act2 := RoundActions.new()
	act2.player_id = 2
	act2.attack_targets.append({"attacker_lane": 1, "target_player_id": 0, "target_lane": 1})

	ResolutionEngine.resolve([act1, act2], ctx)

	# 2 unique attackers < threshold 3 -> both deal 100%
	_check(p0.life == 22, "No Pile-On for 2 attackers: Defender P0 Life is 22 (30 - 8 = 22, both dealt 100%)")


func _test_two_player_backward_compatibility() -> void:
	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	p0.life = 25
	p1.life = 25

	var c0 := CreatureResource.new()
	c0.id = "p0_creature"
	c0.attack = 3
	c0.defense = 1
	p0.lanes[0].append(c0)

	var c1 := CreatureResource.new()
	c1.id = "p1_creature"
	c1.attack = 2
	c1.defense = 2
	p1.lanes[1].append(c1)

	for k in [p0, p1]:
		ctx.kingdoms.append(k)

	# Empty actions array (standard 2p legacy behavior)
	var log: Array = ResolutionEngine.resolve([], ctx)

	var pass_2p: bool = (
		p0.life == 23
		and p1.life == 22
		and log.size() == 6
	)
	_check(pass_2p, "2-Player Compatibility: Sequential both-attack resolves correctly (P0:23, P1:22, log size 6)")
