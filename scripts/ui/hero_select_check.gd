extends Node

const HeroSelectScript = preload("res://scripts/ui/hero_select.gd")

var _passed := 0
var _failed := 0
var _manual := 0

var _emitted_hero: HeroResource = null
var _emitted_cards: Array = []
var _signal_count := 0

func _on_hero_selected(hero: HeroResource, cards: Array) -> void:
	_emitted_hero = hero
	_emitted_cards = cards
	_signal_count += 1

func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[CHECK] PASS: %s" % label)
	else:
		_failed += 1
		print("[CHECK] FAIL: %s" % label)

func _manual_check(label: String) -> void:
	_manual += 1
	print("[CHECK] MANUAL: %s" % label)

func _ready() -> void:
	_test_hero_resources_loaded()
	_test_affinity_filtering()
	_test_hero_select_ui()
	_test_manual_aspects()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("HeroSelectCheck: FAIL")
		get_tree().quit(1)
	else:
		print("HeroSelectCheck: PASS")
		get_tree().quit()

func _test_hero_resources_loaded() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	_check(ignis != null, "hr_ignis loaded from CardDatabase")
	if ignis:
		_check(ignis.display_name == "Ignis", "Ignis display_name is correct")
		_check(ignis.affinity == "fire", "Ignis affinity is 'fire'")
		_check(ignis.starting_life == 25, "Ignis starting_life is 25")
		_check(ignis.passive_trait != "", "Ignis has passive_trait")

	var terras := CardDatabase.get_hero("hr_terras")
	_check(terras != null, "hr_terras loaded from CardDatabase")
	if terras:
		_check(terras.display_name == "Terras", "Terras display_name is correct")
		_check(terras.affinity == "earth", "Terras affinity is 'earth'")
		_check(terras.starting_life == 25, "Terras starting_life is 25")
		_check(terras.passive_trait != "", "Terras has passive_trait")

	var aquos := CardDatabase.get_hero("hr_aquos")
	_check(aquos != null, "hr_aquos loaded from CardDatabase")
	if aquos:
		_check(aquos.display_name == "Aquos", "Aquos display_name is correct")
		_check(aquos.affinity == "water", "Aquos affinity is 'water'")
		_check(aquos.starting_life == 25, "Aquos starting_life is 25")
		_check(aquos.passive_trait != "", "Aquos has passive_trait")

	var all_heroes := CardDatabase.get_all_heroes()
	_check(all_heroes.size() >= 3, "CardDatabase loads at least 3 placeholder heroes (got %d)" % all_heroes.size())

func _test_affinity_filtering() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	var terras := CardDatabase.get_hero("hr_terras")
	var aquos := CardDatabase.get_hero("hr_aquos")

	# 1. Ignis (Fire):
	var fire_cards := CardDatabase.get_eligible_cards_for_hero(ignis)
	var fire_ids: Array[String] = []
	for c in fire_cards:
		fire_ids.append(c.id)

	_check(fire_ids.has("cr_flame_drake"), "Fire hero eligible cards include Flame Drake")
	_check(fire_ids.has("cr_goblin_scout"), "Fire hero eligible cards include Goblin Scout")
	_check(fire_ids.has("sp_fireball"), "Fire hero eligible cards include Fireball")
	_check(fire_ids.has("ls_volcanic_ridge"), "Fire hero eligible cards include Volcanic Ridge")
	_check(not fire_ids.has("cr_ancient_treant"), "Fire hero excludes Earth creature Ancient Treant")
	_check(not fire_ids.has("cr_stone_golem"), "Fire hero excludes Earth creature Stone Golem")
	_check(not fire_ids.has("cr_tide_serpent"), "Fire hero excludes Water creature Tide Serpent")
	_check(not fire_ids.has("sp_healing_rain"), "Fire hero excludes Water spell Healing Rain")
	_check(not fire_ids.has("ls_coral_reef"), "Fire hero excludes Water landscape Coral Reef")
	_check(not fire_ids.has("cr_wind_sprite"), "Fire hero excludes Air creature Wind Sprite")

	# 2. Terras (Earth):
	var earth_cards := CardDatabase.get_eligible_cards_for_hero(terras)
	var earth_ids: Array[String] = []
	for c in earth_cards:
		earth_ids.append(c.id)

	_check(earth_ids.has("cr_ancient_treant"), "Earth hero eligible cards include Ancient Treant")
	_check(earth_ids.has("cr_stone_golem"), "Earth hero eligible cards include Stone Golem")
	_check(not earth_ids.has("cr_flame_drake"), "Earth hero excludes Fire creature Flame Drake")
	_check(not earth_ids.has("sp_fireball"), "Earth hero excludes Fire spell Fireball")
	_check(not earth_ids.has("cr_tide_serpent"), "Earth hero excludes Water creature Tide Serpent")
	_check(not earth_ids.has("sp_healing_rain"), "Earth hero excludes Water spell Healing Rain")
	_check(not earth_ids.has("cr_wind_sprite"), "Earth hero excludes Air creature Wind Sprite")

	# 3. Aquos (Water):
	var water_cards := CardDatabase.get_eligible_cards_for_hero(aquos)
	var water_ids: Array[String] = []
	for c in water_cards:
		water_ids.append(c.id)

	_check(water_ids.has("cr_tide_serpent"), "Water hero eligible cards include Tide Serpent")
	_check(water_ids.has("sp_healing_rain"), "Water hero eligible cards include Healing Rain")
	_check(water_ids.has("ls_coral_reef"), "Water hero eligible cards include Coral Reef")
	_check(not water_ids.has("cr_flame_drake"), "Water hero excludes Fire creature Flame Drake")
	_check(not water_ids.has("sp_fireball"), "Water hero excludes Fire spell Fireball")
	_check(not water_ids.has("cr_ancient_treant"), "Water hero excludes Earth creature Ancient Treant")

	# 4. Universal / neutral card eligibility
	var neutral_creature := CreatureResource.new()
	neutral_creature.id = "cr_test_neutral"
	neutral_creature.affinity = ""
	_check(CardDatabase.is_card_eligible_for_affinity(neutral_creature, "fire"), "Neutral creature eligible for Fire")
	_check(CardDatabase.is_card_eligible_for_affinity(neutral_creature, "earth"), "Neutral creature eligible for Earth")
	_check(CardDatabase.is_card_eligible_for_affinity(neutral_creature, "water"), "Neutral creature eligible for Water")

func _test_hero_select_ui() -> void:
	var hero_select_scene := load("res://scenes/deckbuilder/HeroSelect.tscn") as PackedScene
	_check(hero_select_scene != null, "HeroSelect.tscn loaded successfully")
	if not hero_select_scene:
		return

	var hero_select: Control = hero_select_scene.instantiate() as Control
	_check(hero_select != null, "HeroSelect instantiated successfully")
	add_child(hero_select)

	hero_select.populate_heroes()

	var container: Container = hero_select.hero_container
	_check(container != null, "HeroContainer found in HeroSelect")
	if container:
		_check(container.get_child_count() >= 3, "HeroContainer populated with at least 3 hero cards (got %d)" % container.get_child_count())

		# Check hero card node structure
		var first_card: Node = container.get_child(0)
		_check(first_card.has_node("MarginContainer/VBoxContainer/PortraitRect"), "Hero card has PortraitRect")
		_check(first_card.has_node("MarginContainer/VBoxContainer/NameLabel"), "Hero card has NameLabel")
		_check(first_card.has_node("MarginContainer/VBoxContainer/AffinityLabel"), "Hero card has AffinityLabel")
		_check(first_card.has_node("MarginContainer/VBoxContainer/TraitLabel"), "Hero card has TraitLabel")
		_check(first_card.has_node("MarginContainer/VBoxContainer/SelectButton"), "Hero card has SelectButton")

	# Test signal emission on selection
	_emitted_hero = null
	_emitted_cards = []
	_signal_count = 0

	hero_select.hero_selected.connect(_on_hero_selected)

	# Select Ignis
	var ignis := CardDatabase.get_hero("hr_ignis")
	hero_select.select_hero(ignis)

	_check(_signal_count == 1, "hero_selected signal emitted exactly once on select_hero")
	_check(_emitted_hero != null and _emitted_hero.id == "hr_ignis", "Emitted hero is Ignis")
	_check(hero_select.selected_hero == ignis, "hero_select.selected_hero is Ignis")
	_check(_emitted_cards.size() == CardDatabase.get_eligible_cards_for_hero(ignis).size(), "Emitted cards count matches CardDatabase eligible count")
	_check(hero_select.details_name_label.text.begins_with("Ignis"), "Details name label updated with Ignis")

	# Select Terras via button press simulation
	var terras_card: Node = container.get_node_or_null("HeroCard_hr_terras")
	_check(terras_card != null, "HeroCard_hr_terras exists in container")
	if terras_card:
		var btn: Button = terras_card.get_node_or_null("MarginContainer/VBoxContainer/SelectButton") as Button
		_check(btn != null, "SelectButton exists on Terras card")
		if btn:
			btn.emit_signal("pressed")
			_check(_signal_count == 2, "hero_selected signal emitted on button press")
			_check(_emitted_hero != null and _emitted_hero.id == "hr_terras", "Emitted hero after button press is Terras")
			_check(hero_select.selected_hero.id == "hr_terras", "hero_select.selected_hero updated to Terras")
			_check(hero_select.details_name_label.text.begins_with("Terras"), "Details name label updated with Terras")

	# Select Aquos by ID
	hero_select.select_hero_by_id("hr_aquos")
	_check(_signal_count == 3, "hero_selected signal emitted on select_hero_by_id")
	_check(hero_select.selected_hero.id == "hr_aquos", "hero_select.selected_hero is Aquos")

	hero_select.queue_free()

func _test_manual_aspects() -> void:
	_manual_check("Hero portrait TextureRect layout, scaling, and placeholder artwork")
	_manual_check("HeroCard responsive spacing and visual styling on 16:9 viewport")
	_manual_check("HeroSelect details panel text legibility and font styling")
