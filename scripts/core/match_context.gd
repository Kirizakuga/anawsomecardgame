class_name MatchContext
extends RefCounted

var turn_number: int = 0
var turn_limit: int = 30
var kingdoms: Array[KingdomState] = []
var pacts: Array[Dictionary] = []

func get_kingdom(player_id: int) -> KingdomState:
	for k in kingdoms:
		if k.player_id == player_id:
			return k
	return null

func get_active_kingdoms() -> Array[KingdomState]:
	var active: Array[KingdomState] = []
	for k in kingdoms:
		if not k.is_eliminated:
			active.append(k)
	return active

func is_turn_limit_reached() -> bool:
	return turn_number >= turn_limit
