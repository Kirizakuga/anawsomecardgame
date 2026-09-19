extends Node

# Headless check runner for M2-03: Deck save and load functionality.

const DeckBuilderScene = preload("res://scenes/deckbuilder/DeckBuilder.tscn")
const TEST_SAVE_PATH: String = "user://test_deck_save_m2_03.json"
const TEST_CORRUPT_PATH: String = "user://test_corrupt_m2_03.json"

var _passed := 0
var _failed := 0
var _manual := 0

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

func _cleanup_test_files() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_CORRUPT_PATH):
		DirAccess.remove_absolute(TEST_CORRUPT_PATH)

func _ready() -> void:
	_cleanup_test_files()

	_test_serialization_format()
	_test_save_and_load_roundtrip()
	_test_edge_cases()
	_test_ui_save_load_integration()
	_test_manual_aspects()

	_cleanup_test_files()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("DeckSaveLoadCheck: FAIL")
		get_tree().quit(1)
	else:
		print("DeckSaveLoadCheck: PASS")
		get_tree().quit()

func _create_dummy_card(id: String, name: String, is_landscape: bool = false, affinity: String = "fire") -> CardResource:
	var card: CardResource
	if is_landscape:
		var ls := LandscapeResource.new()
		ls.affected_affinity = affinity
		card = ls
	else:
		var cr := CreatureResource.new()
		cr.affinity = affinity
		cr.attack = 2
		cr.defense = 2
		card = cr
	card.id = id
	card.display_name = name
	card.essence_cost = 1
	return card

func _test_serialization_format() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	_check(ignis != null, "Hero Ignis loaded from CardDatabase")

	var state := DeckBuildState.new(ignis)
	var drake := CardDatabase.get_card("cr_flame_drake")
	var ridge := CardDatabase.get_card("ls_volcanic_ridge")
	_check(drake != null, "Flame drake loaded")
	_check(ridge != null, "Volcanic ridge loaded")

	state.add_card(drake)
	state.add_card(drake)
	state.add_card(ridge)

	var dict := state.to_dict()
	_check(dict.has("version") and dict["version"] == 1, "Dictionary contains version: 1")
	_check(dict.has("hero_id") and dict["hero_id"] == "hr_ignis", "Dictionary hero_id is hr_ignis")
	_check(dict.has("main_deck") and dict["main_deck"].size() == 2, "Dictionary main_deck contains 2 card IDs")
	_check(dict["main_deck"][0] == "cr_flame_drake" and dict["main_deck"][1] == "cr_flame_drake", "Dictionary main_deck IDs match added cards")
	_check(dict.has("landscape_deck") and dict["landscape_deck"].size() == 1, "Dictionary landscape_deck contains 1 card ID")
	_check(dict["landscape_deck"][0] == "ls_volcanic_ridge", "Dictionary landscape_deck ID matches volcanic ridge")

	var json_text := state.to_json()
	_check(json_text.begins_with("{") and json_text.ends_with("}"), "Serialized JSON string is valid JSON object structure")

	var parsed = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "JSON string parsed back into Dictionary")
	_check(parsed["hero_id"] == "hr_ignis", "Parsed JSON has correct hero_id")
	_check(parsed["main_deck"].size() == 2, "Parsed JSON has correct main_deck size")
	_check(parsed["landscape_deck"].size() == 1, "Parsed JSON has correct landscape_deck size")

func _test_save_and_load_roundtrip() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	var original_state := DeckBuildState.new(ignis)

	# Build full valid deck: 30 main cards (10 types x 3), 5 landscape cards (2 types x 2, 1 type x 1)
	# Use available cards from database plus dummy cards if needed
	var drake := CardDatabase.get_card("cr_flame_drake")
	var spark := CardDatabase.get_card("cr_cinder_spark")
	var strike := CardDatabase.get_card("sp_magma_burst")
	var ridge := CardDatabase.get_card("ls_volcanic_ridge")

	# Main deck: 10 types x 3 copies each = 30 cards
	var added_card_ids: Array[String] = []
	for i in range(10):
		var dummy := _create_dummy_card("test_deck_fire_%d" % i, "Fire %d" % i, false, "fire")
		CardDatabase.cards[dummy.id] = dummy
		added_card_ids.append(dummy.id)
		for c in range(3):
			var added := original_state.add_card(dummy)
			if not added:
				push_error("Failed to add dummy card %s" % dummy.id)

	_check(original_state.main_deck.size() == 30, "Original main deck has 30 cards")

	# Landscape deck: 2 types x 2 copies, 1 type x 1 copy = 5 cards
	var ls_ids: Array[String] = []
	for i in range(3):
		var dummy_ls := _create_dummy_card("test_deck_ls_%d" % i, "Landscape %d" % i, true, "fire")
		CardDatabase.cards[dummy_ls.id] = dummy_ls
		ls_ids.append(dummy_ls.id)

	original_state.add_card(CardDatabase.get_card(ls_ids[0]))
	original_state.add_card(CardDatabase.get_card(ls_ids[0]))
	original_state.add_card(CardDatabase.get_card(ls_ids[1]))
	original_state.add_card(CardDatabase.get_card(ls_ids[1]))
	original_state.add_card(CardDatabase.get_card(ls_ids[2]))

	_check(original_state.landscape_deck.size() == 5, "Original landscape deck has 5 cards")
	_check(original_state.is_valid(), "Original deck is VALID per DeckBuildState rules")

	# Save to file
	var save_res := DeckSaveManager.save_deck_to_file(original_state, TEST_SAVE_PATH)
	_check(save_res.get("success", false) == true, "DeckSaveManager saved deck to file successfully")
	_check(FileAccess.file_exists(TEST_SAVE_PATH), "Save file exists on disk")

	# Load into fresh state
	var loaded_state := DeckBuildState.new()
	var load_res := DeckSaveManager.load_deck_from_file(loaded_state, TEST_SAVE_PATH)
	_check(load_res.get("success", false) == true, "DeckSaveManager loaded deck from file successfully")
	_check(load_res.get("missing_ids", []).is_empty(), "No missing card IDs reported")

	# Verify contents match
	_check(loaded_state.hero != null and loaded_state.hero.id == "hr_ignis", "Loaded deck hero is hr_ignis")
	_check(loaded_state.main_deck.size() == 30, "Loaded main deck size is 30")
	_check(loaded_state.landscape_deck.size() == 5, "Loaded landscape deck size is 5")
	_check(loaded_state.get_card_count(added_card_ids[0]) == 3, "Loaded card 0 copy count is 3")
	_check(loaded_state.get_card_count(added_card_ids[1]) == 3, "Loaded card 1 copy count is 3")
	_check(loaded_state.get_landscape_deck_count(ls_ids[0]) == 2, "Loaded landscape 0 count is 2")
	_check(loaded_state.get_landscape_deck_count(ls_ids[2]) == 1, "Loaded landscape 2 count is 1")
	_check(loaded_state.is_valid(), "Loaded deck is VALID identically to original")

func _test_edge_cases() -> void:
	var state := DeckBuildState.new()

	# Missing file
	var missing_res := DeckSaveManager.load_deck_from_file(state, "user://non_existent_file_xyz_123.json")
	_check(missing_res.get("success", false) == false, "Loading nonexistent file returns success: false")
	_check(missing_res.get("error", "") != "", "Missing file returns descriptive error")

	# Corrupted JSON
	var corrupt_file := FileAccess.open(TEST_CORRUPT_PATH, FileAccess.WRITE)
	if corrupt_file:
		corrupt_file.store_string("{ this is not valid json ::: 123")
		corrupt_file.close()

	var corrupt_res := DeckSaveManager.load_deck_from_file(state, TEST_CORRUPT_PATH)
	_check(corrupt_res.get("success", false) == false, "Loading corrupted JSON returns success: false")
	_check(corrupt_res.get("error", "") != "", "Corrupted JSON returns descriptive error")

	# Unknown hero ID and unknown card IDs
	var unknown_data: Dictionary = {
		"version": 1,
		"hero_id": "hr_unknown_ghost",
		"main_deck": ["cr_ghost_1", "cr_flame_drake"],
		"landscape_deck": ["ls_ghost_ls", "ls_volcanic_ridge"]
	}
	var test_unknown_state := DeckBuildState.new()
	var unknown_res := test_unknown_state.load_from_dict(unknown_data)
	_check(unknown_res.get("success", false) == true, "load_from_dict succeeds even with unknown cards")
	var missing_ids: Array = unknown_res.get("missing_ids", [])
	_check(missing_ids.has("hr_unknown_ghost"), "Unknown hero ID is reported in missing_ids")
	_check(missing_ids.has("cr_ghost_1"), "Unknown main card ID is reported in missing_ids")
	_check(missing_ids.has("ls_ghost_ls"), "Unknown landscape card ID is reported in missing_ids")
	_check(test_unknown_state.main_deck.size() == 1, "Known card (cr_flame_drake) loaded while unknown skipped")
	_check(test_unknown_state.landscape_deck.size() == 1, "Known landscape (ls_volcanic_ridge) loaded while unknown skipped")
	_check(test_unknown_state.hero == null, "Hero is null when unknown hero ID was passed")

func _test_ui_save_load_integration() -> void:
	var deck_builder := DeckBuilderScene.instantiate() as DeckBuilder
	_check(deck_builder != null, "DeckBuilder instantiated for save/load UI check")
	add_child(deck_builder)

	var aquos := CardDatabase.get_hero("hr_aquos")
	_check(aquos != null, "Hero Aquos loaded from CardDatabase")
	deck_builder.select_hero(aquos)
	_check(deck_builder.deck_state.hero == aquos, "DeckBuilder hero set to Aquos")

	var serpent := CardDatabase.get_card("cr_tide_serpent")
	var reef := CardDatabase.get_card("ls_coral_reef")
	_check(serpent != null, "cr_tide_serpent loaded")
	_check(reef != null, "ls_coral_reef loaded")
	deck_builder.add_card(serpent)
	deck_builder.add_card(serpent)
	deck_builder.add_card(reef)

	_check(deck_builder.deck_state.main_deck.size() == 2, "DeckBuilder main deck has 2 cards")
	_check(deck_builder.deck_state.landscape_deck.size() == 1, "DeckBuilder landscape deck has 1 card")

	# Save deck via UI method
	var save_res := deck_builder.save_deck(TEST_SAVE_PATH)
	_check(save_res.get("success", false) == true, "deck_builder.save_deck() succeeded")
	_check(FileAccess.file_exists(TEST_SAVE_PATH), "Save file created by DeckBuilder")

	# Clear deck
	deck_builder.clear_deck()
	_check(deck_builder.deck_state.main_deck.is_empty(), "Deck cleared in UI")
	_check(deck_builder.deck_state.landscape_deck.is_empty(), "Landscape deck cleared in UI")
	_check(deck_builder.main_deck_count_label.text == "Main Deck: 0 / 30", "Main deck count label refreshed to 0")

	# Change hero temporarily to Ignis
	var ignis := CardDatabase.get_hero("hr_ignis")
	deck_builder.select_hero(ignis)
	_check(deck_builder.deck_state.hero == ignis, "Temporarily changed hero to Ignis")

	# Load deck via UI method
	var load_res := deck_builder.load_deck(TEST_SAVE_PATH)
	_check(load_res.get("success", false) == true, "deck_builder.load_deck() succeeded")
	_check(deck_builder.deck_state.hero == aquos, "Hero restored to Aquos upon deck load")
	_check(deck_builder.deck_state.main_deck.size() == 2, "Main deck restored with 2 cards")
	_check(deck_builder.deck_state.landscape_deck.size() == 1, "Landscape deck restored with 1 card")
	_check(deck_builder.main_deck_count_label.text == "Main Deck: 2 / 30", "Main deck count label updated to 2 / 30")
	_check(deck_builder.landscape_deck_count_label.text == "Landscape Deck: 1 / 8 (min 5)", "Landscape count label updated to 1 / 8")

	# Test button bindings exist
	_check(deck_builder.save_button != null, "Save button node exists in DeckBuilder")
	_check(deck_builder.load_button != null, "Load button node exists in DeckBuilder")

	remove_child(deck_builder)
	deck_builder.queue_free()

func _test_manual_aspects() -> void:
	_manual_check("Save and Load button styling, placement, and visual feedback in DeckBuilder UI")
	_manual_check("Saved deck file location in user profile directory across app restart")
