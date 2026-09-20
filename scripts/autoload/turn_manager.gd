extends Node

signal phase_changed(phase: Phase)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

signal action_received(player_id: int, actions: RoundActions)
signal waiting_status_changed(is_waiting: bool, pending_player_ids: Array[int])
signal all_actions_collected(actions: Array[RoundActions])

enum Phase { ESSENCE, PLAY, BATTLE, CLEANUP }

var current_phase: Phase = Phase.ESSENCE
var current_turn: int = 0

var pending_player_ids: Array[int] = []
var collected_actions: Dictionary = {} # player_id -> RoundActions
var is_collecting_actions: bool = false
var _active_context: MatchContext = null
var _connected_sources: Dictionary = {} # player_id -> DecisionSource

func start_turn() -> void:
	current_turn += 1
	turn_started.emit(current_turn)
	advance_phase(Phase.ESSENCE)

func advance_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(current_phase)

func next_phase() -> void:
	match current_phase:
		Phase.ESSENCE:
			advance_phase(Phase.PLAY)
		Phase.PLAY:
			advance_phase(Phase.BATTLE)
		Phase.BATTLE:
			advance_phase(Phase.CLEANUP)
		Phase.CLEANUP:
			turn_ended.emit(current_turn)

func start_action_collection(context: MatchContext, sources: Dictionary) -> void:
	cancel_action_collection()
	_active_context = context
	is_collecting_actions = true
	collected_actions.clear()
	pending_player_ids.clear()

	var active_kingdoms := context.get_active_kingdoms()
	for k in active_kingdoms:
		pending_player_ids.append(k.player_id)

	waiting_status_changed.emit(true, pending_player_ids.duplicate())

	# Connect and request from each active player's DecisionSource
	for k in active_kingdoms:
		var pid := k.player_id
		var source: DecisionSource = sources.get(pid, null)
		if source != null:
			_connected_sources[pid] = source
			var cb := func(actions: RoundActions) -> void:
				_on_source_actions_ready(actions)
			source.actions_ready.connect(cb, CONNECT_ONE_SHOT)
			source.request_actions(k, context)

func _on_source_actions_ready(actions: RoundActions) -> void:
	if not is_collecting_actions or actions == null:
		return

	var pid := actions.player_id
	collected_actions[pid] = actions
	pending_player_ids.erase(pid)

	action_received.emit(pid, actions)

	if pending_player_ids.is_empty():
		is_collecting_actions = false
		waiting_status_changed.emit(false, pending_player_ids.duplicate())
		var collected_list := get_collected_actions_list()
		all_actions_collected.emit(collected_list)
		advance_phase(Phase.BATTLE)
	else:
		waiting_status_changed.emit(true, pending_player_ids.duplicate())

func get_collected_actions_list() -> Array[RoundActions]:
	var result: Array[RoundActions] = []
	if _active_context != null:
		for k in _active_context.kingdoms:
			if collected_actions.has(k.player_id):
				result.append(collected_actions[k.player_id])
	else:
		for val in collected_actions.values():
			if val is RoundActions:
				result.append(val)
	return result

func cancel_action_collection() -> void:
	# ponytail: simple disconnect — add explicit source cancel if DecisionSource adds cancellation
	is_collecting_actions = false
	pending_player_ids.clear()
	collected_actions.clear()
	_connected_sources.clear()
	_active_context = null
