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
	_test_case_1_goblin_scout_draw()
	_test_case_2_stone_golem_heal()
	_test_case_3_flame_drake_direct_damage()
	_test_case_4_insufficient_essence()
	_test_case_5_no_floop_effect()
	_test_case_6_card_view_ui()
	_test_case_7_card_database_floop_effects()
	_test_case_8_multiplayer_floop_explicit_targeting()

	print("[CHECK] SUMMARY: %d passed, %d failed, 0 manual" % [_passed, _failed])
	if _failed > 0:
		print("FloopCheck: FAIL")
		get_tree().quit(1)
	else:
		print("FloopCheck: PASS")
		get_tree().quit()

func _test_case_1_goblin_scout_draw() -> void:
	var card: CardResource = load("res://data/cards/creatures/cr_goblin_scout.tres")
	var kingdom := KingdomState.new(0)
	kingdom.essence = 2

	var dummy_card := CardResource.new()
	dummy_card.id = "dummy_1"
	kingdom.deck.append(dummy_card)

	var initial_deck_size := kingdom.deck.size()
	var initial_hand_size := kingdom.hand.size()

	var can_f := FloopResolver.can_floop(card, kingdom)
	_check(can_f, "Case 1: can_floop returns true for cr_goblin_scout with essence=2")

	var res: Dictionary = FloopResolver.resolve_floop(card, kingdom)
	var pass_c1: bool = (
		res.get("success") == true
		and res.get("effect_type") == "draw_card"
		and res.get("cost_paid") == 1
		and kingdom.essence == 1
		and kingdom.hand.size() == initial_hand_size + 1
		and kingdom.deck.size() == initial_deck_size - 1
		and kingdom.hand.back() == dummy_card
	)
	_check(pass_c1, "Case 1: cr_goblin_scout draws card and deducts 1 essence (2 -> 1)")

func _test_case_2_stone_golem_heal() -> void:
	var card: CardResource = load("res://data/cards/creatures/cr_stone_golem.tres")
	var kingdom := KingdomState.new(0)
	kingdom.essence = 1
	kingdom.life = 20

	var can_f := FloopResolver.can_floop(card, kingdom)
	_check(can_f, "Case 2: can_floop returns true for cr_stone_golem with essence=1")

	var res: Dictionary = FloopResolver.resolve_floop(card, kingdom)
	var pass_c2: bool = (
		res.get("success") == true
		and res.get("effect_type") == "heal_life"
		and res.get("cost_paid") == 1
		and kingdom.essence == 0
		and kingdom.life == 22
	)
	_check(pass_c2, "Case 2: cr_stone_golem heals 2 life (20 -> 22) and deducts 1 essence (1 -> 0)")

func _test_case_3_flame_drake_direct_damage() -> void:
	var card: CardResource = load("res://data/cards/creatures/cr_flame_drake.tres")
	var user_kingdom := KingdomState.new(0)
	user_kingdom.essence = 3

	var target_kingdom := KingdomState.new(1)
	target_kingdom.life = 25

	var can_f := FloopResolver.can_floop(card, user_kingdom)
	_check(can_f, "Case 3: can_floop returns true for cr_flame_drake with essence=3")

	var res: Dictionary = FloopResolver.resolve_floop(card, user_kingdom, target_kingdom)
	var pass_c3: bool = (
		res.get("success") == true
		and res.get("effect_type") == "direct_damage"
		and res.get("cost_paid") == 2
		and user_kingdom.essence == 1
		and target_kingdom.life == 23
	)
	_check(pass_c3, "Case 3: cr_flame_drake deals 2 direct damage (25 -> 23) and deducts 2 essence (3 -> 1)")

func _test_case_4_insufficient_essence() -> void:
	var card: CardResource = load("res://data/cards/creatures/cr_flame_drake.tres") # cost 2
	var kingdom := KingdomState.new(0)
	kingdom.essence = 1

	var can_f := FloopResolver.can_floop(card, kingdom)
	_check(not can_f, "Case 4: can_floop returns false when essence (1) < cost (2)")

	var res: Dictionary = FloopResolver.resolve_floop(card, kingdom)
	var pass_c4: bool = (
		res.get("success") == false
		and res.get("reason") == "cannot_floop"
		and kingdom.essence == 1
	)
	_check(pass_c4, "Case 4: resolve_floop fails with insufficient essence, essence unchanged")

func _test_case_5_no_floop_effect() -> void:
	var card: CardResource = load("res://data/cards/creatures/cr_wind_sprite.tres")
	var kingdom := KingdomState.new(0)
	kingdom.essence = 5

	var can_f := FloopResolver.can_floop(card, kingdom)
	_check(not can_f, "Case 5: can_floop returns false for card with no floop effect")

	var res: Dictionary = FloopResolver.resolve_floop(card, kingdom)
	var pass_c5: bool = (
		res.get("success") == false
		and res.get("reason") == "cannot_floop"
		and kingdom.essence == 5
	)
	_check(pass_c5, "Case 5: resolve_floop returns success=false for card with no floop effect")

func _test_case_6_card_view_ui() -> void:
	var card_view_scene: PackedScene = load("res://scenes/match/CardView.tscn")
	var scout: CardResource = load("res://data/cards/creatures/cr_goblin_scout.tres")
	var sprite: CardResource = load("res://data/cards/creatures/cr_wind_sprite.tres")

	var cv1: CardView = card_view_scene.instantiate()
	add_child(cv1)
	cv1.card_data = scout

	var cv1_ok: bool = cv1.floop_button != null and cv1.floop_button.visible == true
	_check(cv1_ok, "Case 6: CardView with floop effect card shows FloopButton")

	var cv2: CardView = card_view_scene.instantiate()
	add_child(cv2)
	cv2.card_data = sprite

	var cv2_ok: bool = cv2.floop_button != null and cv2.floop_button.visible == false
	_check(cv2_ok, "Case 6: CardView with no floop effect card hides FloopButton")

	# Also test floop press on card with no floop effect does not toggle is_flooped
	var initial_flooped: bool = cv2.is_flooped
	cv2._on_floop_pressed()
	_check(cv2.is_flooped == initial_flooped, "Case 6: _on_floop_pressed on no-floop card does not toggle is_flooped")

	cv1.queue_free()
	cv2.queue_free()

func _test_case_7_card_database_floop_effects() -> void:
	if CardDatabase == null:
		_check(false, "Case 7: CardDatabase autoload available")
		return

	var scout := CardDatabase.get_card("cr_goblin_scout")
	var golem := CardDatabase.get_card("cr_stone_golem")
	var drake := CardDatabase.get_card("cr_flame_drake")

	var pass_c7: bool = (
		scout != null
		and scout.floop_effect != null
		and scout.floop_effect.id == "fl_scout_snoop"
		and scout.floop_effect.effect_type == "draw_card"
		and scout.floop_effect.effect_value == 1
		and scout.floop_effect.cost_amount == 1
		and golem != null
		and golem.floop_effect != null
		and golem.floop_effect.id == "fl_golem_fortify"
		and golem.floop_effect.effect_type == "heal_life"
		and golem.floop_effect.effect_value == 2
		and golem.floop_effect.cost_amount == 1
		and drake != null
		and drake.floop_effect != null
		and drake.floop_effect.id == "fl_drake_breath"
		and drake.floop_effect.effect_type == "direct_damage"
		and drake.floop_effect.effect_value == 2
		and drake.floop_effect.cost_amount == 2
	)
	_check(pass_c7, "Case 7: CardDatabase loads 3 cards with floop effects intact")

func _test_case_8_multiplayer_floop_explicit_targeting() -> void:
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	var p2 := KingdomState.new(2)
	p0.life = 25
	p1.life = 25
	p2.life = 25
	p0.essence = 2

	var context := MatchContext.new()
	context.kingdoms = [p0, p1, p2]

	var default_opp: int = context.get_default_opponent_id(0)
	_check(default_opp == 1, "Case 8: Default opponent for P0 in [P0, P1, P2] is P1")

	var drake: CardResource = load("res://data/cards/creatures/cr_flame_drake.tres")

	# P0 queues floop with explicit target P2 (bypassing default P1)
	var p0_source := HumanDecisionSource.new()
	p0_source.request_actions(p0, context)
	p0_source.queue_floop(drake, 2)

	var received: Array[RoundActions] = []
	p0_source.actions_ready.connect(func(acts: RoundActions) -> void:
		received.append(acts)
	, CONNECT_ONE_SHOT)
	p0_source.submit()

	_check(not received.is_empty(), "Case 8: HumanDecisionSource submitted action with explicit floop target")
	var p0_actions: RoundActions = received[0]

	ResolutionEngine.resolve([p0_actions], context)

	var pass_c8: bool = (
		p2.life == 23
		and p1.life == 25
		and p0.essence == 0
	)
	_check(pass_c8, "Case 8: Floop with explicit target_player_id=2 damages P2 (25->23), leaves P1 unharmed (25)")

