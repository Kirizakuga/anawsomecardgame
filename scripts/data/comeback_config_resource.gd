class_name ComebackConfigResource
extends Resource

enum TieMode { ALL_TIED, LOWEST_ID, NONE }

@export var bonus_essence: int = 1
@export var tie_mode: TieMode = TieMode.ALL_TIED
