class_name CardResource
extends Resource

enum CardType { CREATURE, SPELL, LANDSCAPE, HERO }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum Affinity { NEUTRAL, FIRE, WATER, EARTH, AIR }

@export var card_name: String = ""
@export var card_type: CardType = CardType.CREATURE
@export var rarity: Rarity = Rarity.COMMON
@export var affinity: Affinity = Affinity.NEUTRAL
@export var essence_cost: int = 0
@export var description: String = ""
@export var art: Texture2D
@export var floop_description: String = ""
@export var floop_cost: int = 0
