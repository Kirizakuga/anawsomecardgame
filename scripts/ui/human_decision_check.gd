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
	_test_request_actions_initialization()
	_test_queue_methods()
	_test_clear_actions()
	_test_submit_signal()
	_test_ui_drop_integration()
	_test_ui_floop_integration()

	print("[CHECK] SUMMARY: %d passed, %d failed, 0 manual" % [_passed, _failed])
	if _failed > 0:
		print("HumanDecisionCheck: FAIL")
		get_tree().quit(1)
	else:
		print("HumanDecisionCheck: PASS")
		get_tree().quit()

func _test_request_actions_initialization() -> void:
	var source := HumanDecisionSource.new()
	var state := KingdomState.new(42)
	var ctx := MatchContext.new()
	source.request_actions(state, ctx)
	_check(source.pending_actions != null, "Case a: request_actions properly initializes pending_actions")
	_check(source.pending_actions.player_id == 42, "Case a: pending_actions.player_id matches kingdom.player_id (42)")

func _test_queue_methods() -> void:
	var source := HumanDecisionSource.new()
	var state := KingdomState.new(1)
	source.request_actions(state, MatchContext.new())

	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	var drake: CreatureResource = CardDatabase.get_card("cr_flame_drake") as CreatureResource
	var landscape: LandscapeResource = CardDatabase.get_card("ls_volcanic_ridge") as LandscapeResource
	_check(goblin != null and drake != null and landscape != null, "Test cards loaded from CardDatabase")

	source.queue_card_play(goblin, 0)
	_check(source.pending_actions.cards_to_play.size() == 1, "Case b: cards_to_play has 1 entry")
	var play_entry: Dictionary = source.pending_actions.cards_to_play[0]
	_check(play_entry.get("card") == goblin and play_entry.get("lane") == 0, "Case b: cards_to_play recorded correct card and lane")

	source.queue_floop(goblin)
	_check(source.pending_actions.cards_to_floop.size() == 1 and source.pending_actions.cards_to_floop[0] == goblin, "Case c: queue_floop recorded card")

	source.queue_landscape(landscape)
	_check(source.pending_actions.landscapes_to_play.size() == 1 and source.pending_actions.landscapes_to_play[0] == landscape, "queue_landscape recorded landscape")

	source.queue_attack_target(0, 2, 1)
	_check(source.pending_actions.attack_targets.size() == 1, "Case d: queue_attack_target recorded 1 entry")
	var atk_entry: Dictionary = source.pending_actions.attack_targets[0]
	_check(atk_entry.get("attacker_lane") == 0 and atk_entry.get("target_player_id") == 2 and atk_entry.get("target_lane") == 1, "Case d: attack_targets schema matches")

	source.queue_pact_proposal(2, {"non_aggression": true})
	_check(source.pending_actions.pact_proposals.size() == 1, "queue_pact_proposal recorded entry")
	var pact_entry: Dictionary = source.pending_actions.pact_proposals[0]
	_check(pact_entry.get("target_player_id") == 2 and pact_entry.get("terms").get("non_aggression") == true, "pact_proposals schema matches")

	source.queue_betrayal(2)
	_check(source.pending_actions.betrayal_target == 2, "queue_betrayal recorded betrayal_target")

func _test_clear_actions() -> void:
	var source := HumanDecisionSource.new()
	var state := KingdomState.new(1)
	source.request_actions(state, MatchContext.new())
	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	source.queue_card_play(goblin, 0)
	source.queue_floop(goblin)
	source.queue_betrayal(2)
	source.clear_actions()
	_check(source.pending_actions.cards_to_play.is_empty(), "clear_actions cleared cards_to_play")
	_check(source.pending_actions.cards_to_floop.is_empty(), "clear_actions cleared cards_to_floop")
	_check(source.pending_actions.betrayal_target == -1, "clear_actions reset betrayal_target to -1")

func _test_submit_signal() -> void:
	var source := HumanDecisionSource.new()
	var state := KingdomState.new(7)
	source.request_actions(state, MatchContext.new())
	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	source.queue_card_play(goblin, 2)
	source.queue_floop(goblin)

	var received: Array[RoundActions] = []
	var on_actions_ready := func(actions: RoundActions) -> void:
		received.append(actions)
	source.actions_ready.connect(on_actions_ready)
	source.submit()

	_check(not received.is_empty(), "Case e: submit() emitted actions_ready signal")
	var emitted_actions: RoundActions = received[0] if not received.is_empty() else null
	_check(emitted_actions != null and emitted_actions == source.pending_actions, "Case e: emitted actions matches pending_actions")
	_check(emitted_actions != null and emitted_actions.player_id == 7, "Case e: emitted actions has correct player_id (7)")
	_check(emitted_actions != null and emitted_actions.cards_to_play.size() == 1 and emitted_actions.cards_to_play[0].get("lane") == 2, "Case e: emitted actions has queued card play")
	_check(emitted_actions != null and emitted_actions.cards_to_floop.size() == 1 and emitted_actions.cards_to_floop[0] == goblin, "Case e: emitted actions has queued floop")

func _test_ui_drop_integration() -> void:
	var kingdom_scene: PackedScene = load("res://scenes/match/Kingdom.tscn")
	var kingdom_view: KingdomView = kingdom_scene.instantiate()
	add_child(kingdom_view)

	var state := KingdomState.new(0)
	state.essence = 5
	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	state.hand.append(goblin)

	var source := HumanDecisionSource.new()
	source.request_actions(state, MatchContext.new())
	kingdom_view.decision_source = source
	kingdom_view.bind_state(state, true)

	var hand_card_view: CardView = kingdom_view.hand_view.get_child(0) as CardView
	_check(hand_card_view != null, "UI drop: hand contains CardView")

	# Simulate drop into lane 1
	var target_lane: LaneView = kingdom_view.lane_views[1]
	target_lane._drop_data(Vector2.ZERO, {"type": "card", "card_data": goblin, "source_view": hand_card_view})

	_check(source.pending_actions.cards_to_play.size() == 1, "Case f: dropping card into lane queues card play in HumanDecisionSource")
	if source.pending_actions.cards_to_play.size() == 1:
		var entry: Dictionary = source.pending_actions.cards_to_play[0]
		_check(entry.get("card") == goblin and entry.get("lane") == 1, "Case f: queued entry contains correct card and lane index 1")
	else:
		_check(false, "Case f: queued entry contains correct card and lane index 1")

	kingdom_view.queue_free()

func _test_ui_floop_integration() -> void:
	var kingdom_scene: PackedScene = load("res://scenes/match/Kingdom.tscn")
	var kingdom_view: KingdomView = kingdom_scene.instantiate()
	add_child(kingdom_view)

	var state := KingdomState.new(0)
	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	state.lanes[0].append(goblin)

	var source := HumanDecisionSource.new()
	source.request_actions(state, MatchContext.new())
	kingdom_view.decision_source = source
	kingdom_view.bind_state(state, true)

	var lane_view: LaneView = kingdom_view.lane_views[0]
	_check(lane_view.current_card_view != null, "UI floop: lane 0 contains CardView")

	# Trigger floop on lane card view
	if lane_view.current_card_view:
		lane_view.current_card_view.floop_triggered.emit(lane_view.current_card_view)

	_check(source.pending_actions.cards_to_floop.size() == 1, "Case g: triggering floop on lane CardView queues floop in HumanDecisionSource")
	if source.pending_actions.cards_to_floop.size() == 1:
		_check(source.pending_actions.cards_to_floop[0] == goblin, "Case g: queued floop card is goblin")
	else:
		_check(false, "Case g: queued floop card is goblin")

	kingdom_view.queue_free()
