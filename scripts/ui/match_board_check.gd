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

	_test_board_layout_config()
	_test_player_counts()
	_test_helper_methods()
	_test_custom_human_id()

	_manual_check("Visual inspection of 4, 5, and 6 player circular board arrangements in editor/play mode")

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("MatchBoardCheck: FAIL")
		get_tree().quit(1)
	else:
		print("MatchBoardCheck: PASS")
		get_tree().quit(0)

func _create_dummy_states(count: int) -> Array[KingdomState]:
	var states: Array[KingdomState] = []
	for i in range(count):
		var state := KingdomState.new(i)
		state.life = 25
		states.append(state)
	return states

func _test_board_layout_config() -> void:
	var cfg := BoardLayoutConfigResource.new()
	_check(cfg != null, "BoardLayoutConfigResource instantiates")
	_check(cfg.radius_x > 0.0, "BoardLayoutConfigResource has valid radius_x")
	_check(cfg.radius_y > 0.0, "BoardLayoutConfigResource has valid radius_y")
	_check(cfg.bot_scale.x > 0.0 and cfg.bot_scale.y > 0.0, "BoardLayoutConfigResource has valid bot_scale")
	_check(cfg.human_scale.x > 0.0 and cfg.human_scale.y > 0.0, "BoardLayoutConfigResource has valid human_scale")
	_check(cfg.target_viewport_size == Vector2(1152.0, 648.0), "BoardLayoutConfigResource target_viewport_size is 1152x648")

	var res_path := "res://data/board/default_board_layout.tres"
	_check(ResourceLoader.exists(res_path), "default_board_layout.tres exists on disk")
	var loaded_cfg = load(res_path)
	_check(loaded_cfg is BoardLayoutConfigResource, "default_board_layout.tres loads as BoardLayoutConfigResource")

func _test_player_counts() -> void:
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	_check(board_scene != null, "MatchBoard.tscn loaded")
	if board_scene == null:
		return

	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var viewport_rect := Rect2(0.0, 0.0, 1152.0, 648.0)

	for count in [4, 5, 6]:
		var states := _create_dummy_states(count)
		board.setup_board(states, 0)

		# 1. Assert all kingdoms instantiated
		var all_views := board.get_all_kingdom_views()
		_check(all_views.size() == count, "Player count %d: instantiated %d KingdomViews" % [count, count])

		# 2. Assert human player hand visible, bots hand hidden
		var human_view := board.get_kingdom_view(0)
		_check(human_view != null and human_view.hand_view.visible, "Player count %d: human player (0) hand is visible" % count)

		var all_bots_hidden := true
		for p_id in range(1, count):
			var bot_view := board.get_kingdom_view(p_id)
			if bot_view == null or bot_view.hand_view.visible:
				all_bots_hidden = false
				break
		_check(all_bots_hidden, "Player count %d: all bot players (1..%d) have hand hidden" % [count, count - 1])

		# 3. Assert all kingdoms fit inside viewport without clipping
		var all_in_bounds := true
		var rects: Array[Rect2] = []
		for p_id in range(count):
			var r := board.get_kingdom_rect(p_id)
			rects.append(r)
			# Check within [0, 0, 1152, 648] with tolerance for float rounding
			if r.position.x < -0.1 or r.position.y < -0.1 or (r.position.x + r.size.x) > 1152.1 or (r.position.y + r.size.y) > 648.1:
				all_in_bounds = false
				print("Player count %d: Kingdom %d out of bounds! Rect: %s, Viewport: %s" % [count, p_id, r, viewport_rect])
		_check(all_in_bounds, "Player count %d: all kingdoms fit inside viewport [0, 0, 1152, 648] without clipping" % count)

		# 4. Assert no two kingdoms have overlapping Rect2 bounding boxes
		var has_overlap := false
		for i in range(rects.size()):
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					has_overlap = true
					print("Player count %d: Overlap detected between kingdom %d (%s) and kingdom %d (%s)" % [count, i, rects[i], j, rects[j]])
		_check(not has_overlap, "Player count %d: no two kingdoms have overlapping Rect2 bounding boxes" % count)

	board.queue_free()

func _test_helper_methods() -> void:
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var states := _create_dummy_states(4)
	board.setup_board(states, 0)

	# get_kingdom_view
	var kv0 := board.get_kingdom_view(0)
	_check(kv0 != null, "get_kingdom_view returns valid KingdomView for existing player")
	var kv_missing := board.get_kingdom_view(999)
	_check(kv_missing == null, "get_kingdom_view returns null for non-existing player")

	# get_all_kingdom_views
	var all_views := board.get_all_kingdom_views()
	_check(all_views.size() == 4, "get_all_kingdom_views returns all 4 views")

	# get_kingdom_rect
	var rect0 := board.get_kingdom_rect(0)
	_check(rect0.size.x > 0 and rect0.size.y > 0, "get_kingdom_rect returns positive size rect for player 0")
	var rect_missing := board.get_kingdom_rect(999)
	_check(rect_missing == Rect2(), "get_kingdom_rect returns empty Rect2 for missing player")

	# clear_board
	board.clear_board()
	_check(board.get_all_kingdom_views().is_empty(), "clear_board empties kingdom views")
	_check(board.get_kingdom_view(0) == null, "get_kingdom_view returns null after clear_board")

	board.queue_free()

func _test_custom_human_id() -> void:
	var board_scene: PackedScene = load("res://scenes/match/MatchBoard.tscn")
	var board: MatchBoard = board_scene.instantiate()
	add_child(board)

	var states := _create_dummy_states(5)
	# Set player 2 as human
	board.setup_board(states, 2)

	var human_view := board.get_kingdom_view(2)
	_check(human_view != null and human_view.hand_view.visible, "Custom human_player_id 2 has visible hand")

	var bot0 := board.get_kingdom_view(0)
	var bot1 := board.get_kingdom_view(1)
	var bot3 := board.get_kingdom_view(3)
	var bot4 := board.get_kingdom_view(4)
	var bots_ok: bool = bot0 != null and not bot0.hand_view.visible \
		and bot1 != null and not bot1.hand_view.visible \
		and bot3 != null and not bot3.hand_view.visible \
		and bot4 != null and not bot4.hand_view.visible
	_check(bots_ok, "Custom human_player_id: other players (0, 1, 3, 4) have hand hidden")

	# Verify bounds and no overlap with custom human ID
	var rects: Array[Rect2] = []
	var all_in_bounds := true
	for p_id in range(5):
		var r := board.get_kingdom_rect(p_id)
		rects.append(r)
		if r.position.x < -0.1 or r.position.y < -0.1 or (r.position.x + r.size.x) > 1152.1 or (r.position.y + r.size.y) > 648.1:
			all_in_bounds = false
	_check(all_in_bounds, "Custom human_player_id: all kingdoms fit inside viewport [0, 0, 1152, 648]")

	var has_overlap := false
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				has_overlap = true
	_check(not has_overlap, "Custom human_player_id: no two kingdoms overlap")

	board.queue_free()
