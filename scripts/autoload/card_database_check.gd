extends Node

func _ready() -> void:
	assert(CardDatabase != null, "CardDatabase autoload must be registered")
	var all_cards: Array[CardResource] = CardDatabase.get_all_cards()
	assert(all_cards.size() == 10, "CardDatabase must load exactly 10 placeholder cards, got: %d" % all_cards.size())
	
	# Verify specific cards across Creature, Spell, Landscape
	assert(CardDatabase.has_card("cr_goblin_scout"), "Must contain cr_goblin_scout")
	assert(CardDatabase.has_card("sp_fireball"), "Must contain sp_fireball")
	assert(CardDatabase.has_card("ls_coral_reef"), "Must contain ls_coral_reef")
	
	var scout: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	assert(scout != null, "cr_goblin_scout must be a CreatureResource")
	assert(scout.attack == 1 and scout.defense == 1)
	
	print("CardDatabaseCheck: PASS")
	get_tree().quit()
