class_name KingdomState
extends RefCounted

var player_id: int = -1
var hero: HeroResource
var life: int = 25
var essence: int = 0
var hand: Array[CardResource] = []
var deck: Array[CardResource] = []
var discard: Array[CardResource] = []
var lanes: Array[Array] = []
var landscapes: Array[LandscapeResource] = []
var landscape_deck: Array[LandscapeResource] = []
var is_eliminated: bool = false

func _init(p_player_id: int = -1, p_hero: HeroResource = null) -> void:
	player_id = p_player_id
	hero = p_hero
	if hero:
		life = hero.starting_life
	for i in range(3):
		lanes.append([])
