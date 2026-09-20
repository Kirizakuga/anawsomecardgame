class_name PileOnConfigResource
extends Resource

@export var threshold: int = 3
@export var attacker_multipliers: Array[float] = [1.0, 0.75, 0.5, 0.25]

func get_multiplier(attacker_index: int) -> float:
	if attacker_multipliers.is_empty():
		return 1.0
	var idx: int = clampi(attacker_index, 0, attacker_multipliers.size() - 1)
	return attacker_multipliers[idx]
