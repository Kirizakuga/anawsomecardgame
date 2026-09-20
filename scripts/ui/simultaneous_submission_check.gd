extends Node

var _passed := 0
var _failed := 0
var _manual := 0

var _all_actions_emitted := false
var _collected_received: Array[RoundActions] = []

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

class ControllableDecisionSource extends DecisionSource:
	var pending_actions: RoundActions = null
	var kingdom_state: KingdomState = null

	func request_actions(kingdom: KingdomState, _context: MatchContext) -> void:
		kingdom_state = kingdom
		pending_actions = RoundActions.new()
		pending_actions.player_id = kingdom.player_id

	func submit() -> void:
		if pending_actions != null:
			actions_ready.emit(pending_actions)

func _ready() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--negative-test" in args:
		_check(false, "Simulated intentional failure for negative testing verification")

	_test_turn_manager_action_collection_unit()
	_test_order_1_bots_first_human_last()
	_test_order_2_human_first_bots_delayed()
	_test_order_3_shuffled_order()
	_test_cancellation()

	_manual_check("Visual inspection of waiting overlay animation and typography in MatchBoard during multiplayer play")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("SimultaneousSubmissionCheck: FAIL")
		get_tree().quit(1)
	else:
		print("SimultaneousSubmissionCheck: PASS")
		get_tree().quit(0)

func _create_5p_context() -> MatchContext:
	var ctx := MatchContext.new()
	for i in range(5):
		var k := KingdomState.new(i)
		k.life = 25
		ctx.kingdoms.append(k)
	return ctx

func _on_all_actions_collected(actions: Array[RoundActions]) -> void:
	_all_actions_emitted = true
	_collected_received = actions

func _test_turn_manager_action_collection_unit() -> void:
	var ctx := _create_5p_context()
	var sources: Dictionary = {}
	for i in range(5):
		sources[i] = ControllableDecisionSource.new()

	TurnManager.current_phase = TurnManager.Phase.PLAY
	TurnManager.start_action_collection(ctx, sources)

	_check(TurnManager.is_collecting_actions == true, "TurnManager is collecting actions after start")
	_check(TurnManager.pending_player_ids.size() == 5, "TurnManager pending_player_ids has 5 players initially")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "TurnManager remains in PLAY phase initially")

	TurnManager.cancel_action_collection()
	_check(TurnManager.is_collecting_actions == false, "TurnManager is_collecting_actions false after cancel")
	_check(TurnManager.pending_player_ids.is_empty(), "TurnManager pending_player_ids empty after cancel")

func _test_order_1_bots_first_human_last() -> void:
	# Order 1: Bots submit first, human submits last. Resolution does NOT proceed until human submits.
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var ctx := _create_5p_context()
	board.setup_board(ctx.kingdoms, 0)

	var human_source := HumanDecisionSource.new()
	var bot_sources: Array[BotDecisionSource] = []
	var sources: Dictionary = { 0: human_source }

	for i in range(1, 5):
		var b := BotDecisionSource.new(null, 0.0)
		bot_sources.append(b)
		sources[i] = b

	_all_actions_emitted = false
	_collected_received.clear()
	TurnManager.all_actions_collected.connect(_on_all_actions_collected, CONNECT_ONE_SHOT)

	TurnManager.current_phase = TurnManager.Phase.PLAY
	# Request actions — bots submit synchronously during request_actions()
	TurnManager.start_action_collection(ctx, sources)

	# After start, bots (1..4) have submitted immediately, but human (0) has not submitted yet
	_check(TurnManager.is_collecting_actions == true, "Order 1: Still collecting while human pending")
	_check(TurnManager.pending_player_ids == [0], "Order 1: Only human (0) remains in pending_player_ids")
	_check(TurnManager.collected_actions.size() == 4, "Order 1: 4 bot actions collected so far")
	_check(_all_actions_emitted == false, "Order 1: all_actions_collected has NOT emitted before human submits")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "Order 1: TurnManager has NOT advanced to BATTLE before human submits")

	# Now human submits
	human_source.submit()

	_check(_all_actions_emitted == true, "Order 1: all_actions_collected emitted upon human submission")
	_check(TurnManager.is_collecting_actions == false, "Order 1: Collection finished")
	_check(TurnManager.pending_player_ids.is_empty(), "Order 1: pending_player_ids empty")
	_check(TurnManager.current_phase == TurnManager.Phase.BATTLE, "Order 1: TurnManager advanced to BATTLE after all 5 actions")
	_check(_collected_received.size() == 5, "Order 1: 5 RoundActions collected in all_actions_collected payload")

	board.queue_free()

func _test_order_2_human_first_bots_delayed() -> void:
	# Order 2: Human submits first, bots submit delayed/one-by-one.
	# Verify human UI clearly enters "waiting for others" state (is_waiting_visible() == true),
	# resolution does NOT proceed on partial arrivals (1/5, 2/5, 3/5, 4/5),
	# and resolution only proceeds once the 5th action arrives, at which point is_waiting_visible() == false.
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var ctx := _create_5p_context()
	board.setup_board(ctx.kingdoms, 0)

	var human_source := HumanDecisionSource.new()
	var controllable_bots: Array[ControllableDecisionSource] = []
	var sources: Dictionary = { 0: human_source }

	for i in range(1, 5):
		var b := ControllableDecisionSource.new()
		controllable_bots.append(b)
		sources[i] = b

	_all_actions_emitted = false
	_collected_received.clear()
	TurnManager.all_actions_collected.connect(_on_all_actions_collected, CONNECT_ONE_SHOT)

	TurnManager.current_phase = TurnManager.Phase.PLAY
	TurnManager.start_action_collection(ctx, sources)

	_check(board.is_waiting_visible() == false, "Order 2: Waiting overlay not visible before human submits")
	_check(_all_actions_emitted == false, "Order 2: Resolution not triggered at start")

	# Step 1: Human submits first (1/5)
	human_source.submit()

	_check(board.is_waiting_visible() == true, "Order 2: Waiting overlay visible immediately after human submits while others pending")
	_check(_all_actions_emitted == false, "Order 2: Resolution not triggered with 1/5 actions")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "Order 2: Still in PLAY phase at 1/5 actions")
	_check(TurnManager.pending_player_ids.size() == 4, "Order 2: 4 players still pending")

	# Step 2: Bot 1 submits (2/5)
	controllable_bots[0].submit()
	_check(board.is_waiting_visible() == true, "Order 2: Waiting overlay still visible at 2/5 actions")
	_check(_all_actions_emitted == false, "Order 2: Resolution not triggered at 2/5 actions")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "Order 2: Still in PLAY phase at 2/5 actions")

	# Step 3: Bot 2 submits (3/5)
	controllable_bots[1].submit()
	_check(board.is_waiting_visible() == true, "Order 2: Waiting overlay still visible at 3/5 actions")
	_check(_all_actions_emitted == false, "Order 2: Resolution not triggered at 3/5 actions")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "Order 2: Still in PLAY phase at 3/5 actions")

	# Step 4: Bot 3 submits (4/5)
	controllable_bots[2].submit()
	_check(board.is_waiting_visible() == true, "Order 2: Waiting overlay still visible at 4/5 actions")
	_check(_all_actions_emitted == false, "Order 2: Resolution not triggered at 4/5 actions")
	_check(TurnManager.current_phase == TurnManager.Phase.PLAY, "Order 2: Still in PLAY phase at 4/5 actions")

	# Step 5: Bot 4 submits (5/5)
	controllable_bots[3].submit()
	_check(_all_actions_emitted == true, "Order 2: all_actions_collected emitted only when 5th action arrives")
	_check(board.is_waiting_visible() == false, "Order 2: Waiting overlay hidden when all actions collected")
	_check(TurnManager.current_phase == TurnManager.Phase.BATTLE, "Order 2: Advanced to BATTLE phase after 5/5 actions")
	_check(TurnManager.pending_player_ids.is_empty(), "Order 2: pending_player_ids empty after 5/5 actions")

	board.queue_free()

func _test_order_3_shuffled_order() -> void:
	# Order 3: Shuffled/out-of-order arrival (e.g. Bot 2, Human, Bot 0, Bot 3, Bot 1)
	# resolution only fires on the final action.
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var ctx := _create_5p_context()
	board.setup_board(ctx.kingdoms, 0)

	var sources: Dictionary = {}
	for i in range(5):
		sources[i] = ControllableDecisionSource.new()

	_all_actions_emitted = false
	_collected_received.clear()
	TurnManager.all_actions_collected.connect(_on_all_actions_collected, CONNECT_ONE_SHOT)

	TurnManager.current_phase = TurnManager.Phase.PLAY
	TurnManager.start_action_collection(ctx, sources)

	# Submission order: Player 3 (Bot), Player 0 (Human), Player 1 (Bot), Player 4 (Bot), Player 2 (Bot)
	var sequence := [3, 0, 1, 4, 2]
	for idx in range(sequence.size() - 1):
		var pid: int = sequence[idx]
		sources[pid].submit()
		_check(_all_actions_emitted == false, "Order 3: Resolution not triggered after player %d (step %d/5)" % [pid, idx + 1])
		if pid == 0:
			_check(board.is_waiting_visible() == true, "Order 3: Waiting overlay visible after player 0 submits mid-sequence")

	# Final player in sequence: Player 2
	sources[sequence.back()].submit()
	_check(_all_actions_emitted == true, "Order 3: Resolution emitted on final player (%d) in shuffled sequence" % sequence.back())
	_check(board.is_waiting_visible() == false, "Order 3: Waiting overlay hidden upon completion")
	_check(TurnManager.current_phase == TurnManager.Phase.BATTLE, "Order 3: Phase advanced to BATTLE on completion")

	board.queue_free()

func _test_cancellation() -> void:
	var ctx := _create_5p_context()
	var sources: Dictionary = {}
	for i in range(5):
		sources[i] = ControllableDecisionSource.new()

	TurnManager.current_phase = TurnManager.Phase.PLAY
	TurnManager.start_action_collection(ctx, sources)
	sources[0].submit()
	sources[1].submit()
	_check(TurnManager.collected_actions.size() == 2, "Cancellation: 2 actions collected before cancel")

	TurnManager.cancel_action_collection()
	_check(TurnManager.is_collecting_actions == false, "Cancellation: is_collecting_actions false")
	_check(TurnManager.collected_actions.is_empty(), "Cancellation: collected_actions cleared")
	_check(TurnManager.pending_player_ids.is_empty(), "Cancellation: pending_player_ids cleared")
