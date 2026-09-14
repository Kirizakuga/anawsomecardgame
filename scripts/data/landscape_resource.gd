class_name LandscapeResource
extends CardResource

@export var essence_per_turn: int = 1
@export var buffed_affinity: Affinity = Affinity.NEUTRAL
@export var buff_attack: int = 0
@export var buff_defense: int = 0
@export var restricted_affinity: Affinity = Affinity.NEUTRAL

func _init() -> void:
	card_type = CardType.LANDSCAPE
