class_name WinConditionConfigResource
extends Resource

enum TieRule { DRAW, MOST_ESSENCE }

@export var turn_limit: int = 30
@export var tie_rule: TieRule = TieRule.DRAW
