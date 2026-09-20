class_name MatchBoard
extends Control

@export var layout_config: BoardLayoutConfigResource

@onready var waiting_overlay: Control = $WaitingOverlay
@onready var waiting_label: Label = $WaitingOverlay/Label

var _kingdom_views: Dictionary = {}
var _human_player_id: int = 0

func _ready() -> void:
	if TurnManager != null:
		if not TurnManager.action_received.is_connected(_on_turn_manager_action_received):
			TurnManager.action_received.connect(_on_turn_manager_action_received)
		if not TurnManager.all_actions_collected.is_connected(_on_turn_manager_all_actions_collected):
			TurnManager.all_actions_collected.connect(_on_turn_manager_all_actions_collected)

func _get_config() -> BoardLayoutConfigResource:
	if layout_config != null:
		return layout_config
	if ResourceLoader.exists("res://data/board/default_board_layout.tres"):
		var default_res = load("res://data/board/default_board_layout.tres")
		if default_res is BoardLayoutConfigResource:
			return default_res
	return BoardLayoutConfigResource.new()

func setup_board(kingdom_states: Array[KingdomState], human_player_id: int = 0) -> void:
	clear_board()
	hide_waiting_state()
	_human_player_id = human_player_id

	var cfg := _get_config()
	var kingdom_scene: PackedScene = load("res://scenes/match/Kingdom.tscn")
	if kingdom_scene == null:
		push_error("MatchBoard: Failed to load Kingdom.tscn")
		return

	var human_state: KingdomState = null
	var human_index: int = -1
	for i in range(kingdom_states.size()):
		if kingdom_states[i].player_id == human_player_id:
			human_state = kingdom_states[i]
			human_index = i
			break

	if human_state == null and not kingdom_states.is_empty():
		human_state = kingdom_states[0]
		human_index = 0
		_human_player_id = human_state.player_id

	var opponents: Array[KingdomState] = []
	var n := kingdom_states.size()
	if n > 1 and human_index >= 0:
		for offset in range(1, n):
			var idx := (human_index + offset) % n
			opponents.append(kingdom_states[idx])
	elif human_index < 0:
		opponents = kingdom_states.duplicate()

	# Human Kingdom instantiation & setup
	if human_state != null:
		var hv: KingdomView = kingdom_scene.instantiate()
		add_child(hv)
		hv.scale = cfg.human_scale
		hv.bind_state(human_state, true)
		hv.reset_size()
		_kingdom_views[human_state.player_id] = hv

	# Opponent Kingdoms instantiation & setup
	var opp_views: Array[KingdomView] = []
	for opp_state in opponents:
		var ov: KingdomView = kingdom_scene.instantiate()
		add_child(ov)
		ov.scale = cfg.bot_scale
		ov.bind_state(opp_state, false)
		ov.reset_size()
		_kingdom_views[opp_state.player_id] = ov
		opp_views.append(ov)

	# Position human kingdom at bottom center
	if human_state != null and _kingdom_views.has(human_state.player_id):
		var hv: KingdomView = _kingdom_views[human_state.player_id]
		var scaled_size := hv.size * hv.scale
		var h_x := (cfg.target_viewport_size.x - scaled_size.x) * 0.5
		var h_y := cfg.target_viewport_size.y - scaled_size.y - cfg.human_bottom_margin
		hv.position = Vector2(h_x, h_y)

	# Position opponents along circular/elliptical arc
	var m := opp_views.size()
	if m > 0:
		var center := cfg.target_viewport_size * 0.5 + cfg.center_offset
		var start_deg := cfg.arc_start_degrees
		var end_deg := cfg.arc_end_degrees
		if end_deg <= start_deg:
			end_deg += 360.0

		for i in range(m):
			var ov: KingdomView = opp_views[i]
			var scaled_size := ov.size * ov.scale
			var angle_deg: float
			if m == 1:
				angle_deg = 270.0
			else:
				var t := float(i) / float(m - 1)
				angle_deg = lerpf(start_deg, end_deg, t)
			var rad := deg_to_rad(angle_deg)
			var c_x := center.x + cfg.radius_x * cos(rad)
			var c_y := center.y + cfg.radius_y * sin(rad)
			ov.position = Vector2(c_x - scaled_size.x * 0.5, c_y - scaled_size.y * 0.5)

	# Ensure overlay stays on top of kingdom views
	if waiting_overlay != null:
		move_child(waiting_overlay, -1)

func show_waiting_state(message: String = "Waiting for other players...") -> void:
	if waiting_label != null:
		waiting_label.text = message
	if waiting_overlay != null:
		waiting_overlay.visible = true

func hide_waiting_state() -> void:
	if waiting_overlay != null:
		waiting_overlay.visible = false

func is_waiting_visible() -> bool:
	if waiting_overlay != null:
		return waiting_overlay.visible
	return false

func _on_turn_manager_action_received(player_id: int, _actions: RoundActions) -> void:
	if player_id == _human_player_id:
		if TurnManager != null and not TurnManager.pending_player_ids.is_empty():
			show_waiting_state()

func _on_turn_manager_all_actions_collected(_actions: Array[RoundActions]) -> void:
	hide_waiting_state()

func get_kingdom_view(player_id: int) -> KingdomView:
	return _kingdom_views.get(player_id, null)

func get_all_kingdom_views() -> Array[KingdomView]:
	var views: Array[KingdomView] = []
	for v in _kingdom_views.values():
		if v is KingdomView:
			views.append(v)
	return views

func clear_board() -> void:
	for v in _kingdom_views.values():
		if is_instance_valid(v):
			v.queue_free()
	_kingdom_views.clear()

func get_kingdom_rect(player_id: int) -> Rect2:
	if not _kingdom_views.has(player_id):
		return Rect2()
	var kv: KingdomView = _kingdom_views[player_id]
	return Rect2(kv.position, kv.size * kv.scale)
