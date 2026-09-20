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

func _ready() -> void:
	_test_1_atk_vs_def_creature_selection()
	_test_2_empty_vs_blocked_lane_placement()
	_test_3_affordable_floops_evaluation()
	_test_4_essence_and_lane_constraints()
	_test_5_null_archetype_fallback()
	_test_6_noise_variance_control()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("BotAIScoringCheck: FAIL")
		get_tree().quit(1)
	else:
		print("BotAIScoringCheck: PASS")
		get_tree().quit()

func _load_profile(path: String) -> BotArchetypeResource:
	var res = load(path)
	if res is BotArchetypeResource:
		return res as BotArchetypeResource
	return null

## Test 1: Fixed hand with high-ATK creature (Flame Drake 4/1) vs high-DEF creature (Stone Golem 1/5) with 2 essence.
## Aggressive archetype picks Flame Drake; Turtle archetype picks Stone Golem.
func _test_1_atk_vs_def_creature_selection() -> void:
	var agg_profile = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var tur_profile = _load_profile("res://data/bot_profiles/ba_turtle.tres")
	_check(agg_profile != null and tur_profile != null, "Test 1: Aggressive and Turtle profiles loaded")

	var agg_bot := BotAI.new(agg_profile, 0.0)
	var tur_bot := BotAI.new(tur_profile, 0.0)

	var flame_drake := CreatureResource.new()
	flame_drake.id = "cr_test_drake"
	flame_drake.display_name = "Flame Drake"
	flame_drake.attack = 4
	flame_drake.defense = 1
	flame_drake.essence_cost = 2

	var stone_golem := CreatureResource.new()
	stone_golem.id = "cr_test_golem"
	stone_golem.display_name = "Stone Golem"
	stone_golem.attack = 1
	stone_golem.defense = 5
	stone_golem.essence_cost = 2

	# Bot Kingdom with 2 essence
	var bot_kingdom := KingdomState.new(0)
	bot_kingdom.essence = 2
	bot_kingdom.hand = [flame_drake, stone_golem]

	# Opponent Kingdom with empty lanes
	var opp_kingdom := KingdomState.new(1)

	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, opp_kingdom]

	var agg_actions: RoundActions = agg_bot.decide(bot_kingdom, context)
	var agg_picked_drake: bool = (
		agg_actions.cards_to_play.size() == 1
		and agg_actions.cards_to_play[0]["card"] == flame_drake
	)
	_check(agg_picked_drake, "Test 1: Aggressive archetype picks Flame Drake (4/1) over Stone Golem (1/5)")

	# Reset hand for Turtle bot
	bot_kingdom.essence = 2
	bot_kingdom.hand = [flame_drake, stone_golem]

	var tur_actions: RoundActions = tur_bot.decide(bot_kingdom, context)
	var tur_picked_golem: bool = (
		tur_actions.cards_to_play.size() == 1
		and tur_actions.cards_to_play[0]["card"] == stone_golem
	)
	_check(tur_picked_golem, "Test 1: Turtle archetype picks Stone Golem (1/5) over Flame Drake (4/1)")

## Test 2: Empty lane vs blocked lane placement choices under Aggressive vs Turtle.
func _test_2_empty_vs_blocked_lane_placement() -> void:
	var agg_profile = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var tur_profile = _load_profile("res://data/bot_profiles/ba_turtle.tres")

	var agg_bot := BotAI.new(agg_profile, 0.0)
	var tur_bot := BotAI.new(tur_profile, 0.0)

	var creature := CreatureResource.new()
	creature.id = "cr_balanced_soldier"
	creature.display_name = "Balanced Soldier"
	creature.attack = 2
	creature.defense = 2
	creature.essence_cost = 1

	var bot_kingdom := KingdomState.new(0)
	bot_kingdom.essence = 1
	bot_kingdom.hand = [creature]

	# Opponent has Lane 0 empty, Lane 1 occupied by an enemy 2/2 creature
	var opp_kingdom := KingdomState.new(1)
	var opp_creature := CreatureResource.new()
	opp_creature.id = "cr_opp_threat"
	opp_creature.attack = 2
	opp_creature.defense = 2
	opp_kingdom.lanes[1].append(opp_creature)

	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, opp_kingdom]

	var agg_actions: RoundActions = agg_bot.decide(bot_kingdom, context)
	var agg_chose_empty_lane: bool = (
		agg_actions.cards_to_play.size() == 1
		and agg_actions.cards_to_play[0]["lane"] == 0
	)
	_check(agg_chose_empty_lane, "Test 2: Aggressive bot places creature in empty opposing lane 0 for direct damage")

	# Reset for Turtle
	bot_kingdom.essence = 1
	bot_kingdom.hand = [creature]

	var tur_actions: RoundActions = tur_bot.decide(bot_kingdom, context)
	var tur_chose_blocked_lane: bool = (
		tur_actions.cards_to_play.size() == 1
		and tur_actions.cards_to_play[0]["lane"] == 1
	)
	_check(tur_chose_blocked_lane, "Test 2: Turtle bot places creature in blocked opposing lane 1 to defend/absorb")

## Test 3: Affordable floops evaluated properly.
func _test_3_affordable_floops_evaluation() -> void:
	var tur_profile = _load_profile("res://data/bot_profiles/ba_turtle.tres")
	var agg_profile = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var tur_bot := BotAI.new(tur_profile, 0.0)
	var agg_bot := BotAI.new(agg_profile, 0.0)

	var heal_floop := FloopEffectResource.new()
	heal_floop.id = "fl_test_heal"
	heal_floop.cost_type = "essence"
	heal_floop.cost_amount = 1
	heal_floop.effect_type = "heal_life"
	heal_floop.effect_value = 2

	var golem := CreatureResource.new()
	golem.id = "cr_golem_in_lane"
	golem.attack = 1
	golem.defense = 4
	golem.floop_effect = heal_floop

	var dmg_floop := FloopEffectResource.new()
	dmg_floop.id = "fl_test_dmg"
	dmg_floop.cost_type = "essence"
	dmg_floop.cost_amount = 1
	dmg_floop.effect_type = "direct_damage"
	dmg_floop.effect_value = 2

	var drake := CreatureResource.new()
	drake.id = "cr_drake_in_lane"
	drake.attack = 4
	drake.defense = 2
	drake.floop_effect = dmg_floop

	# 3a. Affordable floop is chosen when essence is sufficient
	var bot_kingdom := KingdomState.new(0)
	bot_kingdom.essence = 1
	bot_kingdom.lanes[0].append(golem)
	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, KingdomState.new(1)]

	var actions_affordable: RoundActions = tur_bot.decide(bot_kingdom, context)
	var floop_chosen: bool = (
		actions_affordable.cards_to_floop.size() == 1
		and actions_affordable.cards_to_floop[0] == golem
	)
	_check(floop_chosen, "Test 3a: Affordable floop is selected into cards_to_floop")

	# 3b. Unaffordable floop is NOT chosen
	bot_kingdom.essence = 0
	var actions_unaffordable: RoundActions = tur_bot.decide(bot_kingdom, context)
	var floop_skipped: bool = actions_unaffordable.cards_to_floop.is_empty()
	_check(floop_skipped, "Test 3b: Unaffordable floop is rejected when essence is 0")

	# 3c. Archetype floop preference differentiation
	# Board has both golem (heal) and drake (damage), but only 1 essence available
	bot_kingdom.essence = 1
	bot_kingdom.lanes[0] = [golem]
	bot_kingdom.lanes[1] = [drake]

	var agg_floop_actions: RoundActions = agg_bot.decide(bot_kingdom, context)
	var agg_favored_dmg: bool = (
		agg_floop_actions.cards_to_floop.size() == 1
		and agg_floop_actions.cards_to_floop[0] == drake
	)
	_check(agg_favored_dmg, "Test 3c: Aggressive bot prioritizes direct damage floop over heal floop")

	var tur_floop_actions: RoundActions = tur_bot.decide(bot_kingdom, context)
	var tur_favored_heal: bool = (
		tur_floop_actions.cards_to_floop.size() == 1
		and tur_floop_actions.cards_to_floop[0] == golem
	)
	_check(tur_favored_heal, "Test 3c: Turtle bot prioritizes heal floop over direct damage floop")

## Test 4: Never exceeds available essence or places cards into occupied lanes.
func _test_4_essence_and_lane_constraints() -> void:
	var agg_profile = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var bot := BotAI.new(agg_profile, 0.0)

	var c1 := CreatureResource.new()
	c1.id = "c1"
	c1.attack = 3
	c1.defense = 2
	c1.essence_cost = 2

	var c2 := CreatureResource.new()
	c2.id = "c2"
	c2.attack = 3
	c2.defense = 2
	c2.essence_cost = 2

	var c3 := CreatureResource.new()
	c3.id = "c3"
	c3.attack = 3
	c3.defense = 2
	c3.essence_cost = 2

	var existing_creature := CreatureResource.new()
	existing_creature.id = "existing"
	existing_creature.attack = 1
	existing_creature.defense = 1

	var bot_kingdom := KingdomState.new(0)
	bot_kingdom.essence = 3
	bot_kingdom.hand = [c1, c2, c3]
	# Lane 0 is already occupied!
	bot_kingdom.lanes[0].append(existing_creature)

	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, KingdomState.new(1)]

	var actions: RoundActions = bot.decide(bot_kingdom, context)

	# Only 1 card can be played (costs 2 <= 3; playing 2 would cost 4 > 3)
	var count_ok: bool = actions.cards_to_play.size() == 1
	_check(count_ok, "Test 4a: Bot respects essence budget (plays 1 card of cost 2 with 3 essence)")

	# Card must NOT be placed in occupied lane 0
	var lane_ok: bool = false
	if actions.cards_to_play.size() > 0:
		lane_ok = actions.cards_to_play[0]["lane"] != 0 and actions.cards_to_play[0]["lane"] in [1, 2]
	_check(lane_ok, "Test 4b: Bot never places card into already-occupied lane 0")

	# Multiple plays within budget: essence = 4, lanes 1 and 2 empty -> plays 2 cards
	bot_kingdom.essence = 4
	bot_kingdom.hand = [c1, c2, c3]
	var actions_multi: RoundActions = bot.decide(bot_kingdom, context)
	var multi_ok: bool = actions_multi.cards_to_play.size() == 2
	var total_cost: int = 0
	var lanes_used: Array[int] = []
	for p in actions_multi.cards_to_play:
		total_cost += (p["card"] as CreatureResource).essence_cost
		lanes_used.append(p["lane"])
	var multi_valid: bool = multi_ok and total_cost <= 4 and not (0 in lanes_used) and lanes_used[0] != lanes_used[1]
	_check(multi_valid, "Test 4c: Bot plays multiple affordable cards without exceeding budget or double-occupying lanes")

## Test 5: Fallback when archetype is null.
func _test_5_null_archetype_fallback() -> void:
	var bot_null := BotAI.new(null, 0.0)
	var c := CreatureResource.new()
	c.id = "c_neutral"
	c.attack = 2
	c.defense = 2
	c.essence_cost = 1

	var bot_kingdom := KingdomState.new(0)
	bot_kingdom.essence = 1
	bot_kingdom.hand = [c]

	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, KingdomState.new(1)]

	var actions: RoundActions = bot_null.decide(bot_kingdom, context)
	var pass_null: bool = (
		actions != null
		and actions.cards_to_play.size() == 1
		and actions.cards_to_play[0]["card"] == c
	)
	_check(pass_null, "Test 5: Bot operates with default weights (1.0) when archetype is null")

## Test 6: Noise variance control.
func _test_6_noise_variance_control() -> void:
	var agg_profile = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	# Zero noise: score_card_placement is identical across calls
	var bot_zero := BotAI.new(agg_profile, 0.0)
	var c := CreatureResource.new()
	c.id = "c_noise_test"
	c.attack = 3
	c.defense = 3
	c.essence_cost = 1

	var bot_kingdom := KingdomState.new(0)
	var context := MatchContext.new()
	context.kingdoms = [bot_kingdom, KingdomState.new(1)]

	var s1 := bot_zero.score_card_placement(c, 0, bot_kingdom, context)
	var s2 := bot_zero.score_card_placement(c, 0, bot_kingdom, context)
	_check(s1 == s2, "Test 6a: Under noise_variance=0.0, repeated scores are strictly equal")

	# Non-zero noise: variance is within [-0.05, 0.05]
	var bot_noise := BotAI.new(agg_profile, 0.05)
	var diff_found := false
	for i in range(20):
		var sn := bot_noise.score_card_placement(c, 0, bot_kingdom, context)
		if absf(sn - s1) > 0.0:
			diff_found = true
		_check(absf(sn - s1) <= 0.051, "Test 6b: Noise perturbation stays bounded by noise_variance")
	_check(diff_found, "Test 6c: Under noise_variance=0.05, non-deterministic perturbation is active")
