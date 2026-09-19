extends Node

signal match_ended(winner_id: int)

enum MatchMode { TWO_PLAYER, FREE_FOR_ALL }

var match_mode: MatchMode = MatchMode.TWO_PLAYER
var player_count: int = 2
var match_context: MatchContext
var decision_sources: Dictionary = {}
var is_match_over: bool = false
var winner: int = -1

func setup_match(heroes: Array[HeroResource], sources: Array[DecisionSource]) -> void:
	reset_match()
	match_context = MatchContext.new()
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
	var best_id: int = -1
	var best_life: int = -1
	var is_tie: bool = false
	for k in kingdoms:
		if k.life > best_life:
			best_life = k.life
			best_id = k.player_id
			is_tie = false
		elif k.life == best_life:
			is_tie = true
	if is_tie:
		return -1
	return best_id
