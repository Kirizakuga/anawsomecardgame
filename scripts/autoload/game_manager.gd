extends Node

signal match_ended(winner_id: int)

const WinConditionConfigResource = preload("res://scripts/data/win_condition_config_resource.gd")

enum MatchMode { TWO_PLAYER, FREE_FOR_ALL }

var match_mode: MatchMode = MatchMode.TWO_PLAYER
var player_count: int = 2
var match_context: MatchContext
var decision_sources: Dictionary = {}
var is_match_over: bool = false
var winner: int = -1
var win_condition_config: WinConditionConfigResource = null

func _ready() -> void:
	_ensure_win_condition_config()

func _ensure_win_condition_config() -> void:
	if win_condition_config == null:
		var config_path := "res://data/match/default_win_condition_config.tres"
		if ResourceLoader.exists(config_path):
			win_condition_config = load(config_path)
		else:
			win_condition_config = WinConditionConfigResource.new()

func setup_match(heroes: Array[HeroResource], sources: Array[DecisionSource]) -> void:
	reset_match()
	match_context = MatchContext.new()
	_ensure_win_condition_config()
	if win_condition_config != null and match_context.turn_limit == 30:
		match_context.turn_limit = win_condition_config.turn_limit
	player_count = heroes.size()
	if player_count > 2:
		match_mode = MatchMode.FREE_FOR_ALL
	else:
		match_mode = MatchMode.TWO_PLAYER
	for i in range(heroes.size()):
		var kingdom := KingdomState.new(i, heroes[i])
		match_context.kingdoms.append(kingdom)
		decision_sources[i] = sources[i]

func reset_match() -> void:
	is_match_over = false
	winner = -1
	match_context = null
	decision_sources.clear()

func end_match(declared_winner: int) -> void:
	if is_match_over:
		return
	is_match_over = true
	winner = declared_winner
	match_ended.emit(winner)

func check_win_condition(context: MatchContext = null) -> int:
	_ensure_win_condition_config()
	var ctx: MatchContext = context if context != null else match_context
	if ctx == null:
		return -1
	if is_match_over:
		return winner

	# Eliminate any kingdom whose life dropped to 0 or below
	for k in ctx.kingdoms:
		if k.life <= 0:
			k.is_eliminated = true

	var alive := ctx.get_active_kingdoms()
	if alive.size() == 1:
		end_match(alive[0].player_id)
		return winner
	elif alive.is_empty():
		end_match(-1)
		return winner

	if ctx.is_turn_limit_reached():
		var best_id := _highest_life_player(alive)
		end_match(best_id)
		return winner

	return -1

func _highest_life_player(kingdoms: Array[KingdomState]) -> int:
	if kingdoms.is_empty():
		return -1

	var max_life: int = kingdoms[0].life
	for k in kingdoms:
		if k.life > max_life:
			max_life = k.life

	var tied_life: Array[KingdomState] = []
	for k in kingdoms:
		if k.life == max_life:
			tied_life.append(k)

	if tied_life.size() == 1:
		return tied_life[0].player_id

	_ensure_win_condition_config()
	var tie_rule := WinConditionConfigResource.TieRule.DRAW
	if win_condition_config != null:
		tie_rule = win_condition_config.tie_rule

	match tie_rule:
		WinConditionConfigResource.TieRule.DRAW:
			return -1
		WinConditionConfigResource.TieRule.MOST_ESSENCE:
			var max_essence: int = tied_life[0].essence
			for k in tied_life:
				if k.essence > max_essence:
					max_essence = k.essence
			var tied_essence: Array[KingdomState] = []
			for k in tied_life:
				if k.essence == max_essence:
					tied_essence.append(k)
			if tied_essence.size() == 1:
				return tied_essence[0].player_id
			return -1

	return -1
