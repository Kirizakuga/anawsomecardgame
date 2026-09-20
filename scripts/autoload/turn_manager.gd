extends Node

signal phase_changed(phase: Phase)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

signal action_received(player_id: int, actions: RoundActions)
signal waiting_status_changed(is_waiting: bool, pending_player_ids: Array[int])
signal all_actions_collected(actions: Array[RoundActions])
signal comeback_bonus_awarded(recipient_ids: Array[int], bonus_essence: int)

const ComebackConfigResource = preload("res://scripts/data/comeback_config_resource.gd")

enum Phase { ESSENCE, PLAY, BATTLE, CLEANUP }

var current_phase: Phase = Phase.ESSENCE
var current_turn: int = 0

var pending_player_ids: Array[int] = []
var collected_actions: Dictionary = {} # player_id -> RoundActions
var is_collecting_actions: bool = false
var _active_context: MatchContext = null
var _connected_sources: Dictionary = {} # player_id -> DecisionSource
var comeback_config: ComebackConfigResource = null

func _ready() -> void:
	_ensure_comeback_config()

func _ensure_comeback_config() -> void:
	if comeback_config == null:
		var config_path := "res://data/combat/default_comeback_config.tres"
		if ResourceLoader.exists(config_path):
			comeback_config = load(config_path)
		else:
			comeback_config = ComebackConfigResource.new()

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
			if source is HumanDecisionSource and PactManager != null:
				source.target_validator = func(from_id: int, to_id: int) -> bool:
					return PactManager.can_attack(from_id, to_id)
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

func apply_comeback_bonus(context: MatchContext) -> Dictionary:
	# ponytail: manual bonus invocation — integrate into automated phase loop in M4-08
	_ensure_comeback_config()
	var result: Dictionary = {
		"recipient_ids": [] as Array[int],
		"bonus_essence": 0,
		"min_life": -1
	}
	if context == null:
		return result

	var active_kingdoms: Array[KingdomState] = []
	for k in context.get_active_kingdoms():
		if k.life > 0:
			active_kingdoms.append(k)

	if active_kingdoms.size() < 2:
		return result

	var min_life: int = active_kingdoms[0].life
	for k in active_kingdoms:
		if k.life < min_life:
			min_life = k.life
	result["min_life"] = min_life

	var all_same_life: bool = true
	for k in active_kingdoms:
		if k.life != min_life:
			all_same_life = false
			break

	if all_same_life:
		return result

	var lowest_kingdoms: Array[KingdomState] = []
	for k in active_kingdoms:
		if k.life == min_life:
			lowest_kingdoms.append(k)

	var bonus: int = comeback_config.bonus_essence if comeback_config != null else 1
	var recipients: Array[int] = []
	var tie_mode = comeback_config.tie_mode if comeback_config != null else ComebackConfigResource.TieMode.ALL_TIED

	if lowest_kingdoms.size() == 1:
		recipients.append(lowest_kingdoms[0].player_id)
	else:
		match tie_mode:
			ComebackConfigResource.TieMode.ALL_TIED:
				for k in lowest_kingdoms:
					recipients.append(k.player_id)
			ComebackConfigResource.TieMode.LOWEST_ID:
				var min_id: int = lowest_kingdoms[0].player_id
				for k in lowest_kingdoms:
					if k.player_id < min_id:
						min_id = k.player_id
				recipients.append(min_id)
			ComebackConfigResource.TieMode.NONE:
				pass

	for pid in recipients:
		var k := context.get_kingdom(pid)
		if k != null:
			k.essence += bonus

	if not recipients.is_empty():
		result["recipient_ids"] = recipients
		result["bonus_essence"] = bonus
		comeback_bonus_awarded.emit(recipients, bonus)

	return result

