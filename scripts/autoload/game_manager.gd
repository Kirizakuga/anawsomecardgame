extends Node

enum MatchMode { TWO_PLAYER, FREE_FOR_ALL }

var match_mode: MatchMode = MatchMode.TWO_PLAYER
var player_count: int = 2
var match_context: MatchContext
var decision_sources: Dictionary = {}

func setup_match(heroes: Array[HeroResource], sources: Array[DecisionSource]) -> void:
	match_context = MatchContext.new()
	player_count = heroes.size()
	if player_count > 2:
		match_mode = MatchMode.FREE_FOR_ALL
	for i in range(heroes.size()):
		var kingdom := KingdomState.new(i, heroes[i])
		match_context.kingdoms.append(kingdom)
		decision_sources[i] = sources[i]

func check_win_condition() -> int:
	var alive := match_context.get_active_kingdoms()
	if alive.size() == 1:
		return alive[0].player_id
	if match_context.is_turn_limit_reached():
		return _highest_life_player(alive)
	return -1

func _highest_life_player(kingdoms: Array[KingdomState]) -> int:
	var best_id: int = -1
	var best_life: int = -1
	for k in kingdoms:
		if k.life > best_life:
			best_life = k.life
			best_id = k.player_id
	return best_id
