class_name CreatureResource
extends CardResource

@export var attack: int = 0
@export var defense: int = 0

func _init() -> void:
	card_type = CardType.CREATURE
