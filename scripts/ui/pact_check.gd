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

	_test_pact_manager_proposal_and_acceptance()
	_test_active_pact_blocks_attacks()
	_test_essence_lending()
	_test_pact_proposal_popup()

	_manual_check("PactProposalPopup UI styling, layout in 4-6p MatchBoard, and button click feedback")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("PactCheck: FAIL")
		get_tree().quit(1)
	else:
		print("PactCheck: PASS")
		get_tree().quit(0)

func _test_pact_manager_proposal_and_acceptance() -> void:
	PactManager.reset()

	var proposed_signals: Array = []
	var formed_signals: Array = []
	var broken_signals: Array = []

	var c_prop = func(from_p: int, to_p: int): proposed_signals.append([from_p, to_p])
	var c_form = func(p_a: int, p_b: int): formed_signals.append([p_a, p_b])
	var c_brk = func(breaker: int, victim: int): broken_signals.append([breaker, victim])

	PactManager.pact_proposed.connect(c_prop)
	PactManager.pact_formed.connect(c_form)
	PactManager.pact_broken.connect(c_brk)

	_check(not PactManager.has_pact(0, 1), "Initial: No pact between 0 and 1")
	_check(not PactManager.has_pact(1, 0), "Initial: No pact between 1 and 0 (bilateral)")

	# Propose from 0 to 1
	var prop_ok := PactManager.propose_pact(0, 1)
	_check(prop_ok, "Propose: P0 proposing to P1 returns true")
	_check(PactManager.is_pact_proposed(0, 1), "Propose: is_pact_proposed(0, 1) is true")
	_check(not PactManager.is_pact_proposed(1, 0), "Propose: is_pact_proposed(1, 0) is false (directed)")
	_check(proposed_signals.size() == 1 and proposed_signals[0] == [0, 1], "Propose: pact_proposed signal emitted with [0, 1]")
	_check(not PactManager.has_pact(0, 1), "Propose: Pact is not active until accepted")

	# Accept from 1 to 0
	var acc_ok := PactManager.accept_pact(1, 0)
	_check(acc_ok, "Accept: P1 accepting P0 returns true")
	_check(formed_signals.size() == 1, "Accept: pact_formed signal emitted")
	_check(PactManager.has_pact(0, 1), "Accept: has_pact(0, 1) is true")
	_check(PactManager.has_pact(1, 0), "Accept: has_pact(1, 0) is true (bilateral)")
	_check(not PactManager.is_pact_proposed(0, 1), "Accept: pending proposal cleared after formation")
	_check(PactManager.get_pact_allies(0) == [1], "Allies: P0 allies list contains P1")
	_check(PactManager.get_pact_allies(1) == [0], "Allies: P1 allies list contains P0")

	# Mutual proposal auto-acceptance
	PactManager.propose_pact(2, 3)
	_check(PactManager.is_pact_proposed(2, 3), "Mutual: P2 proposed to P3")
	PactManager.propose_pact(3, 2)
	_check(PactManager.has_pact(2, 3), "Mutual: P3 counter-proposing to P2 automatically forms pact")
	_check(PactManager.has_pact(3, 2), "Mutual: bilateral check for P3 and P2")

	# Break pact
	var brk_ok := PactManager.break_pact(0, 1)
	_check(brk_ok, "Break: P0 breaking pact with P1 returns true")
	_check(broken_signals.size() == 1 and broken_signals[0] == [0, 1], "Break: pact_broken signal emitted with breaker and victim")
	_check(not PactManager.has_pact(0, 1), "Break: has_pact(0, 1) is false")
	_check(not PactManager.has_pact(1, 0), "Break: has_pact(1, 0) is false")

	PactManager.pact_proposed.disconnect(c_prop)
	PactManager.pact_formed.disconnect(c_form)
	PactManager.pact_broken.disconnect(c_brk)

func _test_active_pact_blocks_attacks() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	var p2 := KingdomState.new(2)
	for k in [p0, p1, p2]:
		k.life = 25
		ctx.kingdoms.append(k)

	# Form pact between 0 and 1
	PactManager.accept_pact(0, 1)

	# 1. UI / Decision logic checks
	_check(not PactManager.can_attack(0, 1), "Attack Check: PactManager blocks P0 attacking allied P1")
	_check(not PactManager.can_attack(1, 0), "Attack Check: PactManager blocks P1 attacking allied P0")
	_check(PactManager.can_attack(0, 2), "Attack Check: PactManager permits P0 attacking neutral P2")

	# MatchBoard targeting check
	var mb := MatchBoard.new()
	_check(not mb.can_target_for_attack(0, 1), "MatchBoard: can_target_for_attack(0, 1) is false for pact allies")
	_check(mb.can_target_for_attack(0, 2), "MatchBoard: can_target_for_attack(0, 2) is true for neutral opponents")
	mb.free()

	# HumanDecisionSource validation
	var source := HumanDecisionSource.new()
	source.request_actions(p0, ctx)
	source.target_validator = func(from_id: int, to_id: int) -> bool:
		return PactManager.can_attack(from_id, to_id)

	_check(not source.can_target_for_attack(1), "HumanDecisionSource: can_target_for_attack(1) returns false for ally")
	_check(source.can_target_for_attack(2), "HumanDecisionSource: can_target_for_attack(2) returns true for neutral")

	var q_ally := source.queue_attack_target(0, 1, 0)
	_check(not q_ally, "HumanDecisionSource: queue_attack_target to ally returns false")
	_check(source.pending_actions.attack_targets.is_empty(), "HumanDecisionSource: ally attack not added to attack_targets")

	var q_neutral := source.queue_attack_target(0, 2, 0)
	_check(q_neutral, "HumanDecisionSource: queue_attack_target to neutral returns true")
	_check(source.pending_actions.attack_targets.size() == 1, "HumanDecisionSource: neutral attack added to attack_targets")

	# 2. ResolutionEngine combat resolution check
	# Put attacker in P0 lane 0
	var golem: CreatureResource = load("res://data/cards/creatures/cr_stone_golem.tres").duplicate()
	p0.lanes[0].append(golem) # ATK = 2

	# Force an action targeting allied P1 despite UI
	var act0 := RoundActions.new()
	act0.player_id = 0
	act0.attack_targets.append({"attacker_lane": 0, "target_player_id": 1, "target_lane": 0})

	var act1 := RoundActions.new()
	act1.player_id = 1

	var log: Array = ResolutionEngine.resolve([act0, act1], ctx)

	_check(p1.life == 25, "ResolutionEngine: Allied P1 took NO damage from P0 attack (life remains 25)")

	var has_blocked_entry := false
	for entry in log:
		if entry is Dictionary and entry.get("step") == "combat_blocked_by_pact":
			has_blocked_entry = true
			break
	_check(has_blocked_entry, "ResolutionEngine: combat_blocked_by_pact recorded in resolution log")

	# Now break pact and verify attack deals damage
	PactManager.break_pact(0, 1)
	var log2: Array = ResolutionEngine.resolve([act0, act1], ctx)
	_check(p1.life == 23, "ResolutionEngine: After pact broken, attack damages P1 (25 -> 23)")

func _test_essence_lending() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	p0.essence = 3
	p1.essence = 1
	ctx.kingdoms.append(p0)
	ctx.kingdoms.append(p1)

	# 1. Lending without pact fails
	var lend_no_pact := PactManager.lend_essence(0, 1, ctx, 1)
	_check(not lend_no_pact, "Lend: Lending without active pact returns false")
	_check(p0.essence == 3 and p1.essence == 1, "Lend: Essences unchanged when lending without pact")

	# 2. Form pact and lend 1 essence
	PactManager.accept_pact(0, 1)

	var signal_data: Array = []
	var c_lend = func(from_p: int, to_p: int, amt: int): signal_data.append([from_p, to_p, amt])
	PactManager.essence_lent.connect(c_lend)

	var lend_ok := PactManager.lend_essence(0, 1, ctx, 1)
	_check(lend_ok, "Lend: Lending 1 essence with active pact returns true")
	_check(p0.essence == 2, "Lend: Donor P0 essence decreased by 1 (3 -> 2)")
	_check(p1.essence == 2, "Lend: Receiver P1 essence increased by 1 (1 -> 2)")
	_check(signal_data.size() == 1 and signal_data[0] == [0, 1, 1], "Lend: essence_lent signal emitted with [0, 1, 1]")

	# 3. Lending second time in same turn is blocked (1 per turn limit)
	var lend_second := PactManager.lend_essence(0, 1, ctx, 1)
	_check(not lend_second, "Lend Limit: Second lend in same turn is blocked (returns false)")
	_check(p0.essence == 2 and p1.essence == 2, "Lend Limit: Essences unchanged on blocked 2nd lend")

	# 4. Turn reset clears limit
	PactManager.reset_turn_limits()
	_check(PactManager.can_lend_essence(0, 1, ctx, 1), "Lend Reset: can_lend_essence returns true after reset_turn_limits")
	var lend_next_turn := PactManager.lend_essence(0, 1, ctx, 1)
	_check(lend_next_turn, "Lend Reset: Lending succeeds in next turn")
	_check(p0.essence == 1 and p1.essence == 3, "Lend Reset: Essences updated correctly (P0: 1, P1: 3)")

	# 5. Insufficient essence check
	p0.essence = 0
	PactManager.reset_turn_limits()
	var lend_broke := PactManager.lend_essence(0, 1, ctx, 1)
	_check(not lend_broke, "Lend Essence: Lending with 0 donor essence returns false")

	PactManager.essence_lent.disconnect(c_lend)

func _test_pact_proposal_popup() -> void:
	PactManager.reset()

	var ctx := MatchContext.new()
	var p0 := KingdomState.new(0)
	var p1 := KingdomState.new(1)
	var p2 := KingdomState.new(2)
	var p3 := KingdomState.new(3)
	p0.life = 25
	p0.essence = 3
	for k in [p0, p1, p2, p3]:
		k.life = 25
		ctx.kingdoms.append(k)

	var popup_scene: PackedScene = load("res://scenes/ui/PactProposalPopup.tscn")
	_check(popup_scene != null, "PactProposalPopup: Scene loaded successfully")
	if popup_scene == null:
		return

	var popup = popup_scene.instantiate()
	add_child(popup)
	popup.setup(0, ctx)

	# Verify rows created for opponents (1, 2, 3)
	_check(popup.row_map.has(1), "Popup: Row created for Player 1")
	_check(popup.row_map.has(2), "Popup: Row created for Player 2")
	_check(popup.row_map.has(3), "Popup: Row created for Player 3")
	_check(not popup.row_map.has(0), "Popup: No row created for local Player 0")

	# Test Propose via popup
	var sent_targets: Array = []
	var c_sent = func(t: int): sent_targets.append(t)
	popup.proposal_sent.connect(c_sent)

	var row1: HBoxContainer = popup.row_map[1]
	var prop_btn1: Button = row1.get_node("ProposeButton")
	prop_btn1.pressed.emit()

	_check(sent_targets == [1], "Popup: proposal_sent signal emitted with target 1")
	_check(PactManager.is_pact_proposed(0, 1), "Popup: PactManager recorded proposal to Player 1")

	# Test Accept via popup: Player 2 proposes to Player 0
	PactManager.propose_pact(2, 0)
	popup.refresh()

	var accepted_targets: Array = []
	var c_acc = func(t: int): accepted_targets.append(t)
	popup.pact_accepted.connect(c_acc)

	var row2: HBoxContainer = popup.row_map[2]
	var acc_btn2: Button = row2.get_node("AcceptButton")
	_check(acc_btn2.visible, "Popup: Accept button is visible for incoming proposal from Player 2")
	acc_btn2.pressed.emit()

	_check(accepted_targets == [2], "Popup: pact_accepted signal emitted with target 2")
	_check(PactManager.has_pact(0, 2), "Popup: PactManager formed pact with Player 2")

	# Test Lend via popup: Player 0 lends to Player 2
	var lent_targets: Array = []
	var c_lent = func(t: int): lent_targets.append(t)
	popup.essence_lend_requested.connect(c_lent)

	row2 = popup.row_map[2]
	var lend_btn2: Button = row2.get_node("LendButton")
	_check(lend_btn2.visible, "Popup: Lend button is visible for allied Player 2")
	lend_btn2.pressed.emit()

	_check(lent_targets == [2], "Popup: essence_lend_requested signal emitted for Player 2")
	_check(p0.essence == 2, "Popup: P0 essence reduced by 1 via popup lend")
	_check(p2.essence == 1, "Popup: P2 essence increased by 1 via popup lend")

	# Test Close button
	var closed_tracker: Array[bool] = [false]
	popup.closed.connect(func(): closed_tracker[0] = true)
	popup.close_button.pressed.emit()
	_check(closed_tracker[0], "Popup: closed signal emitted on close button press")
	_check(not popup.visible, "Popup: popup hidden after close")

	popup.queue_free()
