class_name CombatResolver
extends RefCounted

## Resolves combat between two facing KingdomStates across 3 lanes.
## Mutates KingdomStates in place (removes destroyed creatures, reduces life)
## and returns an array of log dictionaries per lane.
static func resolve_combat(attacker: KingdomState, defender: KingdomState) -> Array[Dictionary]:
	var combat_log: Array[Dictionary] = []
	if attacker == null or defender == null:
		return combat_log

	for lane_idx in range(3):
		combat_log.append(resolve_lane(attacker, defender, lane_idx))

	return combat_log


## Resolves combat for a single lane index.
static func resolve_lane(attacker: KingdomState, defender: KingdomState, lane_idx: int) -> Dictionary:
	return resolve_attack(attacker, defender, lane_idx, lane_idx, 1.0)


## Resolves a single attack from an attacker lane against a defender lane with an optional damage multiplier.
static func resolve_attack(attacker: KingdomState, defender: KingdomState, attacker_lane_idx: int, target_lane_idx: int = -1, damage_multiplier: float = 1.0, bonus_attack: int = 0) -> Dictionary:
	if target_lane_idx < 0:
		target_lane_idx = attacker_lane_idx

	var attacker_lane: Array = attacker.lanes[attacker_lane_idx] if (attacker != null and attacker_lane_idx >= 0 and attacker_lane_idx < attacker.lanes.size()) else []
	var defender_lane: Array = defender.lanes[target_lane_idx] if (defender != null and target_lane_idx >= 0 and target_lane_idx < defender.lanes.size()) else []

	var attacker_creature: CreatureResource = attacker_lane[0] as CreatureResource if not attacker_lane.is_empty() else null
	var defender_creature: CreatureResource = defender_lane[0] as CreatureResource if not defender_lane.is_empty() else null

	var attacker_id: int = attacker.player_id if attacker != null else -1
	var defender_id: int = defender.player_id if defender != null else -1

	if attacker_creature == null:
		return {
			"lane": attacker_lane_idx,
			"target_lane": target_lane_idx,
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"attacker_card": null,
			"defender_card": defender_creature,
			"outcome": "empty",
			"damage": 0,
			"net_damage": 0,
			"life_damage": 0,
			"blocker_destroyed": false,
			"multiplier": damage_multiplier,
			"effective_attack": 0,
			"bonus_attack": 0,
		}

	if defender == null or defender.is_eliminated:
		return {
			"lane": attacker_lane_idx,
			"target_lane": target_lane_idx,
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"attacker_card": attacker_creature,
			"defender_card": null,
			"outcome": "target_eliminated",
			"damage": 0,
			"net_damage": 0,
			"life_damage": 0,
			"blocker_destroyed": false,
			"multiplier": damage_multiplier,
			"effective_attack": 0,
			"bonus_attack": bonus_attack,
		}

	var base_attack: int = attacker_creature.attack + bonus_attack
	var effective_attack: int = maxi(0, int(round(float(base_attack) * damage_multiplier)))

	if defender_creature != null:
		# Blocked: creature vs creature.
		# Defense is damage reduction: net_damage = max(0, effective_attack - DEF).
		# Blocker is destroyed if net_damage > 0. No retaliation, no overflow to Life.
		var net_damage: int = maxi(0, effective_attack - defender_creature.defense)
		var blocker_destroyed: bool = net_damage > 0

		if blocker_destroyed:
			defender_lane.clear()
			defender.discard.append(defender_creature)
			return {
				"lane": attacker_lane_idx,
				"target_lane": target_lane_idx,
				"attacker_id": attacker_id,
				"defender_id": defender_id,
				"attacker_card": attacker_creature,
				"defender_card": defender_creature,
				"outcome": "blocked_destroyed",
				"damage": net_damage,
				"net_damage": net_damage,
				"life_damage": 0,
				"blocker_destroyed": true,
				"multiplier": damage_multiplier,
				"effective_attack": effective_attack,
				"bonus_attack": bonus_attack,
			}
		else:
			return {
				"lane": attacker_lane_idx,
				"target_lane": target_lane_idx,
				"attacker_id": attacker_id,
				"defender_id": defender_id,
				"attacker_card": attacker_creature,
				"defender_card": defender_creature,
				"outcome": "blocked_survived",
				"damage": 0,
				"net_damage": 0,
				"life_damage": 0,
				"blocker_destroyed": false,
				"multiplier": damage_multiplier,
				"effective_attack": effective_attack,
				"bonus_attack": bonus_attack,
			}
	else:
		# Unblocked: direct damage to Kingdom Life = effective_attack
		var direct_damage: int = effective_attack
		defender.life -= direct_damage
		if defender.life <= 0:
			defender.is_eliminated = true

		return {
			"lane": attacker_lane_idx,
			"target_lane": target_lane_idx,
			"attacker_id": attacker_id,
			"defender_id": defender_id,
			"attacker_card": attacker_creature,
			"defender_card": null,
			"outcome": "unblocked_damage",
			"damage": direct_damage,
			"net_damage": direct_damage,
			"life_damage": direct_damage,
			"blocker_destroyed": false,
			"multiplier": damage_multiplier,
			"effective_attack": effective_attack,
			"bonus_attack": bonus_attack,
		}
