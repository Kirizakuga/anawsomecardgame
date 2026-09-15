class_name CardResource
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export var essence_cost: int = 0
@export var rarity: Rarity = Rarity.COMMON
@export var art: Texture2D
@export var floop_effect: FloopEffectResource