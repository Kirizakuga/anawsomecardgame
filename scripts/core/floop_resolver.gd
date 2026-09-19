class_name FloopResolver
extends RefCounted

static func can_floop(card: CardResource, kingdom: KingdomState) -> bool:
	if card == null or card.floop_effect == null or kingdom == null:
		return false
	if card.floop_effect.cost_type == "essence":
		return kingdom.essence >= card.floop_effect.cost_amount
	return true

static func resolve_floop(card: CardResource, user_kingdom: KingdomState, target_kingdom: KingdomState = null) -> Dictionary:
	if not can_floop(card, user_kingdom):
		return {"success": false, "reason": "cannot_floop"}

	var effect: FloopEffectResource = card.floop_effect
	if effect.cost_type == "essence":
		user_kingdom.essence -= effect.cost_amount

	match effect.effect_type:
		"draw_card":
			if not user_kingdom.deck.is_empty():
				user_kingdom.hand.append(user_kingdom.deck.pop_front())
		"heal_life":
			user_kingdom.life += effect.effect_value
		"direct_damage":
			if target_kingdom:
				target_kingdom.life -= effect.effect_value
				if target_kingdom.life <= 0:
					target_kingdom.is_eliminated = true
		"buff_attack":
			if card is CreatureResource:
				(card as CreatureResource).attack += effect.effect_value

	return {
		"success": true,
		"effect_type": effect.effect_type,
		"effect_value": effect.effect_value,
		"cost_paid": effect.cost_amount
	}
