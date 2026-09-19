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
	var attacker_lane: Array = attacker.lanes[lane_idx] if lane_idx < attacker.lanes.size() else []
	var defender_lane: Array = defender.lanes[lane_idx] if lane_idx < defender.lanes.size() else []

	var attacker_creature: CreatureResource = attacker_lane[0] as CreatureResource if not attacker_lane.is_empty() else null
	var defender_creature: CreatureResource = defender_lane[0] as CreatureResource if not defender_lane.is_empty() else null

	if attacker_creature == null:
		return {
			"lane": lane_idx,
			"attacker_id": attacker.player_id,
			"defender_id": defender.player_id,
			"attacker_card": null,
			"defender_card": defender_creature,
			"outcome": "empty",
			"damage": 0,
			"net_damage": 0,
			"life_damage": 0,
			"blocker_destroyed": false,
		}

	if defender_creature != null:
		# Blocked: creature vs creature.
		# Defense is damage reduction: net_damage = max(0, ATK - DEF).
		# Blocker is destroyed if net_damage > 0. No retaliation, no overflow to Life.
		var net_damage: int = maxi(0, attacker_creature.attack - defender_creature.defense)
		var blocker_destroyed: bool = net_damage > 0

		if blocker_destroyed:
			defender_lane.clear()
			defender.discard.append(defender_creature)
			return {
				"lane": lane_idx,
				"attacker_id": attacker.player_id,
				"defender_id": defender.player_id,
				"attacker_card": attacker_creature,
				"defender_card": defender_creature,
				"outcome": "blocked_destroyed",
				"damage": net_damage,
				"net_damage": net_damage,
				"life_damage": 0,
				"blocker_destroyed": true,
			}
		else:
			return {
				"lane": lane_idx,
				"attacker_id": attacker.player_id,
				"defender_id": defender.player_id,
				"attacker_card": attacker_creature,
				"defender_card": defender_creature,
				"outcome": "blocked_survived",
				"damage": 0,
				"net_damage": 0,
				"life_damage": 0,
				"blocker_destroyed": false,
			}
	else:
		# Unblocked: direct damage to Kingdom Life = ATK
		var direct_damage: int = maxi(0, attacker_creature.attack)
		defender.life -= direct_damage
		if defender.life <= 0:
			defender.is_eliminated = true

		return {
			"lane": lane_idx,
			"attacker_id": attacker.player_id,
			"defender_id": defender.player_id,
			"attacker_card": attacker_creature,
			"defender_card": null,
			"outcome": "unblocked_damage",
			"damage": direct_damage,
			"net_damage": direct_damage,
			"life_damage": direct_damage,
			"blocker_destroyed": false,
		}
