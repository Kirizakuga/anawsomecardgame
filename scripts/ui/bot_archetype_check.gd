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
	_test_profiles_exist_and_load()
	_test_weights_non_negative()
	_test_archetype_differentiations()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("BotArchetypeCheck: FAIL")
		get_tree().quit(1)
	else:
		print("BotArchetypeCheck: PASS")
		get_tree().quit()

func _load_profile(path: String) -> BotArchetypeResource:
	var res = load(path)
	if res is BotArchetypeResource:
		return res as BotArchetypeResource
	return null

func _test_profiles_exist_and_load() -> void:
	var agg = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var opp = _load_profile("res://data/bot_profiles/ba_opportunist.tres")
	var loy = _load_profile("res://data/bot_profiles/ba_loyalist.tres")
	var tur = _load_profile("res://data/bot_profiles/ba_turtle.tres")

	_check(agg != null, "Aggressive profile loads as BotArchetypeResource")
	_check(opp != null, "Opportunist profile loads as BotArchetypeResource")
	_check(loy != null, "Loyalist profile loads as BotArchetypeResource")
	_check(tur != null, "Turtle profile loads as BotArchetypeResource")

	if agg != null:
		_check(agg.id == "ba_aggressive" and agg.archetype_name == "Aggressive" and not agg.description.is_empty(), "Aggressive metadata populated")
	if opp != null:
		_check(opp.id == "ba_opportunist" and opp.archetype_name == "Opportunist" and not opp.description.is_empty(), "Opportunist metadata populated")
	if loy != null:
		_check(loy.id == "ba_loyalist" and loy.archetype_name == "Loyalist" and not loy.description.is_empty(), "Loyalist metadata populated")
	if tur != null:
		_check(tur.id == "ba_turtle" and tur.archetype_name == "Turtle" and not tur.description.is_empty(), "Turtle metadata populated")

func _test_weights_non_negative() -> void:
	var profiles: Array[BotArchetypeResource] = [
		_load_profile("res://data/bot_profiles/ba_aggressive.tres"),
		_load_profile("res://data/bot_profiles/ba_opportunist.tres"),
		_load_profile("res://data/bot_profiles/ba_loyalist.tres"),
		_load_profile("res://data/bot_profiles/ba_turtle.tres")
	]

	for p in profiles:
		if p == null:
			continue
		var non_neg = (
			p.aggression_weight >= 0.0 and
			p.defense_weight >= 0.0 and
			p.pact_loyalty_weight >= 0.0 and
			p.betrayal_opportunism_weight >= 0.0 and
			p.floop_preference_weight >= 0.0
		)
		_check(non_neg, "%s weights are all non-negative" % p.archetype_name)

func _test_archetype_differentiations() -> void:
	var agg = _load_profile("res://data/bot_profiles/ba_aggressive.tres")
	var opp = _load_profile("res://data/bot_profiles/ba_opportunist.tres")
	var loy = _load_profile("res://data/bot_profiles/ba_loyalist.tres")
	var tur = _load_profile("res://data/bot_profiles/ba_turtle.tres")

	if agg == null or opp == null or loy == null or tur == null:
		_check(false, "Cannot test differentiations because profiles failed to load")
		return

	# Aggressive: highest aggression_weight, lowest pact_loyalty_weight
	var agg_has_highest_aggression = (
		agg.aggression_weight > opp.aggression_weight and
		agg.aggression_weight > loy.aggression_weight and
		agg.aggression_weight > tur.aggression_weight
	)
	var agg_has_lowest_pact = (
		agg.pact_loyalty_weight < opp.pact_loyalty_weight and
		agg.pact_loyalty_weight < loy.pact_loyalty_weight and
		agg.pact_loyalty_weight < tur.pact_loyalty_weight
	)
	_check(agg_has_highest_aggression, "Aggressive has highest aggression_weight across all archetypes")
	_check(agg_has_lowest_pact, "Aggressive has lowest pact_loyalty_weight across all archetypes")

	# Opportunist: highest betrayal_opportunism_weight, low pact_loyalty_weight
	var opp_has_highest_betrayal = (
		opp.betrayal_opportunism_weight > agg.betrayal_opportunism_weight and
		opp.betrayal_opportunism_weight > loy.betrayal_opportunism_weight and
		opp.betrayal_opportunism_weight > tur.betrayal_opportunism_weight
	)
	var opp_low_pact = opp.pact_loyalty_weight < loy.pact_loyalty_weight and opp.pact_loyalty_weight < tur.pact_loyalty_weight
	_check(opp_has_highest_betrayal, "Opportunist has highest betrayal_opportunism_weight across all archetypes")
	_check(opp_low_pact, "Opportunist has lower pact_loyalty_weight than Loyalist and Turtle")

	# Loyalist: highest pact_loyalty_weight, lowest betrayal_opportunism_weight
	var loy_has_highest_pact = (
		loy.pact_loyalty_weight > agg.pact_loyalty_weight and
		loy.pact_loyalty_weight > opp.pact_loyalty_weight and
		loy.pact_loyalty_weight > tur.pact_loyalty_weight
	)
	var loy_has_lowest_betrayal = (
		loy.betrayal_opportunism_weight < agg.betrayal_opportunism_weight and
		loy.betrayal_opportunism_weight < opp.betrayal_opportunism_weight and
		loy.betrayal_opportunism_weight < tur.betrayal_opportunism_weight
	)
	_check(loy_has_highest_pact, "Loyalist has highest pact_loyalty_weight across all archetypes")
	_check(loy_has_lowest_betrayal, "Loyalist has lowest betrayal_opportunism_weight across all archetypes")

	# Turtle: highest defense_weight, lowest aggression_weight
	var tur_has_highest_defense = (
		tur.defense_weight > agg.defense_weight and
		tur.defense_weight > opp.defense_weight and
		tur.defense_weight > loy.defense_weight
	)
	var tur_has_lowest_aggression = (
		tur.aggression_weight < agg.aggression_weight and
		tur.aggression_weight < opp.aggression_weight and
		tur.aggression_weight < loy.aggression_weight
	)
	_check(tur_has_highest_defense, "Turtle has highest defense_weight across all archetypes")
	_check(tur_has_lowest_aggression, "Turtle has lowest aggression_weight across all archetypes")
