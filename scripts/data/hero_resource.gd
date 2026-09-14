class_name HeroResource
extends Resource

@export var hero_name: String = ""
@export var affinity: CardResource.Affinity = CardResource.Affinity.NEUTRAL
@export var portrait: Texture2D
@export var passive_description: String = ""
@export var starting_life: int = 25
@export var ultimate_card: CardResource
