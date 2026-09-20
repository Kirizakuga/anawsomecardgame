extends Node

signal pact_formed(player_a: int, player_b: int)
signal pact_broken(breaker: int, victim: int)
signal pact_proposed(from_player: int, to_player: int)
signal essence_lent(from_player: int, to_player: int, amount: int)

const PactConfigResource = preload("res://scripts/data/pact_config_resource.gd")

var config: PactConfigResource = null

var _active_pacts: Dictionary = {} # canonical key "min:max" -> {"player_a": int, "player_b": int}
var _proposals: Dictionary = {}    # "from:to" -> true
var _essence_lent_this_turn: Dictionary = {} # player_id -> int amount

func _ready() -> void:
	_ensure_config()
	if TurnManager != null:
		if not TurnManager.turn_started.is_connected(_on_turn_started):
			TurnManager.turn_started.connect(_on_turn_started)

func _ensure_config() -> void:
	if config == null:
		var path := "res://data/pact/default_pact_config.tres"
		if ResourceLoader.exists(path):
			config = load(path)
		else:
			config = PactConfigResource.new()

func _on_turn_started(_turn_number: int) -> void:
	reset_turn_limits()

func _canonical_pact_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

func _proposal_key(from_p: int, to_p: int) -> String:
	return "%d:%d" % [from_p, to_p]

func has_pact(player_a: int, player_b: int) -> bool:
	if player_a == player_b:
		return false
	return _active_pacts.has(_canonical_pact_key(player_a, player_b))

func is_pact_proposed(from_player: int, to_player: int) -> bool:
	if from_player == to_player:
		return false
	return _proposals.has(_proposal_key(from_player, to_player))

func propose_pact(from_player: int, to_player: int) -> bool:
	if from_player == to_player:
		return false
	if has_pact(from_player, to_player):
		return false

	# If target already proposed to us, accept automatically
	if is_pact_proposed(to_player, from_player):
		accept_pact(from_player, to_player)
		return true

	_proposals[_proposal_key(from_player, to_player)] = true
	pact_proposed.emit(from_player, to_player)
	return true

func accept_pact(player_a: int, player_b: int) -> bool:
	if player_a == player_b:
		return false
	if has_pact(player_a, player_b):
		return false

	_proposals.erase(_proposal_key(player_a, player_b))
	_proposals.erase(_proposal_key(player_b, player_a))

	var key := _canonical_pact_key(player_a, player_b)
	_active_pacts[key] = {
		"player_a": mini(player_a, player_b),
		"player_b": maxi(player_a, player_b),
	}
	pact_formed.emit(player_a, player_b)
	return true

func break_pact(breaker: int, victim: int) -> bool:
	if not has_pact(breaker, victim):
		return false

	var key := _canonical_pact_key(breaker, victim)
	_active_pacts.erase(key)
	pact_broken.emit(breaker, victim)
	return true

func get_pact_allies(player_id: int) -> Array[int]:
	var allies: Array[int] = []
	for pact in _active_pacts.values():
		if pact["player_a"] == player_id:
			allies.append(pact["player_b"])
		elif pact["player_b"] == player_id:
			allies.append(pact["player_a"])
	allies.sort()
	return allies

func get_active_pacts() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for pact in _active_pacts.values():
		list.append(pact.duplicate())
	return list

func can_attack(attacker_id: int, defender_id: int) -> bool:
	if attacker_id == defender_id:
		return false
	if has_pact(attacker_id, defender_id):
		return false
	return true

func can_lend_essence(from_player: int, to_player: int, context: MatchContext, amount: int = 1) -> bool:
	if not has_pact(from_player, to_player):
		return false
	if from_player == to_player or amount <= 0:
		return false

	_ensure_config()
	var max_lend: int = config.max_essence_lend_per_turn if config != null else 1
	var already: int = _essence_lent_this_turn.get(from_player, 0)
	if already + amount > max_lend:
		return false

	if context == null:
		return false

	var donor: KingdomState = context.get_kingdom(from_player)
	var receiver: KingdomState = context.get_kingdom(to_player)
	if donor == null or receiver == null:
		return false
	if donor.is_eliminated or receiver.is_eliminated:
		return false
	if donor.essence < amount:
		return false

	return true

func lend_essence(from_player: int, to_player: int, context: MatchContext, amount: int = 1) -> bool:
	if not can_lend_essence(from_player, to_player, context, amount):
		return false

	var donor: KingdomState = context.get_kingdom(from_player)
	var receiver: KingdomState = context.get_kingdom(to_player)
	donor.essence -= amount
	receiver.essence += amount

	_essence_lent_this_turn[from_player] = _essence_lent_this_turn.get(from_player, 0) + amount
	essence_lent.emit(from_player, to_player, amount)
	return true

func reset_turn_limits() -> void:
	_essence_lent_this_turn.clear()

func reset() -> void:
	_active_pacts.clear()
	_proposals.clear()
	_essence_lent_this_turn.clear()

func sync_to_context(context: MatchContext) -> void:
	if context == null:
		return
	context.pacts.clear()
	for pact in get_active_pacts():
		context.pacts.append(pact)
