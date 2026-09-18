extends Node

func _ready() -> void:
	var card_view_scene: PackedScene = load("res://scenes/match/CardView.tscn")
	assert(card_view_scene != null, "CardView scene should load")

	var card_view: CardView = card_view_scene.instantiate()
	add_child(card_view)

	var creature: CreatureResource = load("res://data/cards/creatures/cr_goblin_scout.tres")
	assert(creature != null, "Goblin scout should load")

	card_view.card_data = creature
	assert(card_view.name_label.text == "Goblin Scout")
	assert(card_view.cost_label.text == "1")
	assert(card_view.attack_label.text == "ATK: 1")
	assert(card_view.defense_label.text == "DEF: 1")
	assert(card_view.attack_label.visible == true)

	# Test drag payload structure
	var drag_data: Variant = card_view._get_drag_data(Vector2.ZERO)
	assert(drag_data is Dictionary)
	assert(drag_data["type"] == "card")
	assert(drag_data["card_data"] == creature)
	assert(drag_data["source_view"] == card_view)
	assert(card_view.modulate.a == 0.5, "Card should dim during drag")
	card_view._notification(Control.NOTIFICATION_DRAG_END)
	assert(card_view.modulate.a == 1.0, "Card should snap back full opacity on drag end")

	# Test null card data clears texture
	card_view.card_data = null
	assert(card_view.art_rect.texture == null, "Texture should clear when card_data is null")
	card_view.card_data = creature

	# Test floop visual toggle
	assert(card_view.is_flooped == false)
	assert(card_view.rotation_degrees == 0.0)
	card_view.is_flooped = true
	assert(card_view.rotation_degrees == 90.0)

	# Test spell card hiding attack/defense labels
	var spell: SpellResource = load("res://data/cards/spells/sp_fireball.tres")
	card_view.card_data = spell
	assert(card_view.attack_label.visible == false)
	assert(card_view.defense_label.visible == false)
	assert(card_view.cost_label.text == "3")

	print("CardViewCheck: PASS")
	get_tree().quit()
