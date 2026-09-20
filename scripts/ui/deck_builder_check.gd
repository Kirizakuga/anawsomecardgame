extends Node

const DeckBuilderScene = preload("res://scenes/deckbuilder/DeckBuilder.tscn")

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

func _ready() -> void:
	_test_deck_build_state_logic()
	_test_landscape_separation_and_limits()
	_test_validation_rules()
	_test_deck_builder_ui()
	_test_manual_aspects()

	print("[CHECK] SUMMARY: %d passed, %d failed, %d manual" % [_passed, _failed, _manual])
	if _failed > 0:
		print("DeckBuilderCheck: FAIL")
		get_tree().quit(1)
	else:
		print("DeckBuilderCheck: PASS")
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

func _test_deck_build_state_logic() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	_check(ignis != null, "Hero Ignis loaded for state tests")

	var state := DeckBuildState.new(ignis)
	_check(state.hero == ignis, "DeckBuildState initialized with hero")
	_check(state.main_deck.is_empty(), "Main deck initialized empty")
	_check(state.landscape_deck.is_empty(), "Landscape deck initialized empty")

	var drake := CardDatabase.get_card("cr_flame_drake")
	_check(drake != null, "cr_flame_drake loaded from CardDatabase")

	# Test 1: Adding cards increments count and tracks copies
	var add_1 := state.add_card(drake)
	_check(add_1, "1st copy of cr_flame_drake added successfully")
	_check(state.main_deck.size() == 1, "Main deck count is 1 after 1st add")
	_check(state.get_card_count("cr_flame_drake") == 1, "Card copy count is 1")
	_check(state.get_main_deck_count("cr_flame_drake") == 1, "Main deck copy count is 1")

	var add_2 := state.add_card(drake)
	var add_3 := state.add_card(drake)
	_check(add_2 and add_3, "2nd and 3rd copies of cr_flame_drake added successfully")
	_check(state.main_deck.size() == 3, "Main deck size is 3 after adding 3 copies")
	_check(state.get_card_count("cr_flame_drake") == 3, "Card copy count is 3")

	# Test 2: Attempting to add 4th copy is rejected
	_check(not state.can_add_card(drake), "can_add_card returns false for 4th copy")
	_check(state.get_add_card_error(drake) == "max_copies_reached", "Error code is max_copies_reached")
	var add_4 := state.add_card(drake)
	_check(not add_4, "Adding 4th copy of card is rejected")
	_check(state.main_deck.size() == 3, "Main deck size remains 3 after rejected 4th copy")
	_check(state.get_card_count("cr_flame_drake") == 3, "Copy count remains 3 after rejected 4th copy")

	# Test 3: Attempting to add 31st card to main deck is rejected
	# Add 9 more distinct card IDs with 3 copies each = 27 more cards (total 30)
	for i in range(1, 10):
		var test_card := _create_dummy_card("test_fire_%d" % i, "Test Fire %d" % i, false, "fire")
		for copy in range(3):
			var added := state.add_card(test_card)
			if not added:
				push_error("Failed to add test card %s copy %d" % [test_card.id, copy])

	_check(state.main_deck.size() == 30, "Main deck reached max limit of exactly 30 cards (got %d)" % state.main_deck.size())

	var extra_card := _create_dummy_card("test_fire_extra", "Extra Fire Card", false, "fire")
	_check(not state.can_add_card(extra_card), "can_add_card returns false when main deck has 30 cards")
	_check(state.get_add_card_error(extra_card) == "main_deck_full", "Error code is main_deck_full")
	var add_31 := state.add_card(extra_card)
	_check(not add_31, "Attempting to add 31st card to main deck is rejected")
	_check(state.main_deck.size() == 30, "Main deck size remains 30 after rejected 31st card")

	# Test 6 (part 1): Removing cards from main deck decrements count
	var removed := state.remove_card_by_id("cr_flame_drake")
	_check(removed, "remove_card_by_id removed one copy of cr_flame_drake")
	_check(state.main_deck.size() == 29, "Main deck size decremented to 29")
	_check(state.get_card_count("cr_flame_drake") == 2, "cr_flame_drake count decremented to 2")

	# Can now add extra card into the freed slot
	var add_into_freed := state.add_card(extra_card)
	_check(add_into_freed, "Added card into freed slot (back to 30 cards)")
	_check(state.main_deck.size() == 30, "Main deck size is back to 30")

func _test_landscape_separation_and_limits() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	var state := DeckBuildState.new(ignis)

	# Fill main deck to 30 cards
	for i in range(10):
		var dummy := _create_dummy_card("main_card_%d" % i, "Main Card %d" % i, false, "fire")
		for c in range(3):
			state.add_card(dummy)
	_check(state.main_deck.size() == 30, "State has 30 main-deck cards")

	# Test 4: Adding a LandscapeCard adds to landscape sub-deck, not main deck
	var ridge := CardDatabase.get_card("ls_volcanic_ridge")
	_check(ridge != null, "ls_volcanic_ridge loaded from CardDatabase")
	_check(ridge is LandscapeResource, "ls_volcanic_ridge is LandscapeResource")

	_check(state.can_add_card(ridge), "can_add_card returns true for Landscape even when main deck is full (30/30)")
	var add_ls_1 := state.add_card(ridge)
	_check(add_ls_1, "Landscape card added successfully")
	_check(state.main_deck.size() == 30, "Main deck size remains 30 after landscape added (not incremented)")
	_check(state.landscape_deck.size() == 1, "Landscape sub-deck size incremented to 1")
	_check(state.get_landscape_deck_count("ls_volcanic_ridge") == 1, "Landscape sub-deck copy count is 1")

	# Test 5: Landscape sub-deck cannot exceed 8 cards & max 3 copies per card
	state.add_card(ridge)
	state.add_card(ridge)
	_check(state.landscape_deck.size() == 3, "Landscape sub-deck has 3 copies of volcanic ridge")
	_check(not state.can_add_card(ridge), "4th copy of landscape card is rejected")

	var ls_b := _create_dummy_card("ls_fire_b", "Fire Landscape B", true, "fire")
	state.add_card(ls_b)
	state.add_card(ls_b)
	state.add_card(ls_b)
	_check(state.landscape_deck.size() == 6, "Landscape sub-deck has 6 cards")

	var ls_c := _create_dummy_card("ls_fire_c", "Fire Landscape C", true, "fire")
	state.add_card(ls_c)
	state.add_card(ls_c)
	_check(state.landscape_deck.size() == 8, "Landscape sub-deck reached maximum of 8 cards")

	var ls_d := _create_dummy_card("ls_fire_d", "Fire Landscape D", true, "fire")
	_check(not state.can_add_card(ls_d), "can_add_card returns false when landscape sub-deck has 8 cards")
	_check(state.get_add_card_error(ls_d) == "landscape_deck_full", "Error code is landscape_deck_full")
	var add_9th_ls := state.add_card(ls_d)
	_check(not add_9th_ls, "Attempting to add 9th landscape card is rejected")
	_check(state.landscape_deck.size() == 8, "Landscape sub-deck size remains 8")

	# Test 6 (part 2): Removing landscape decrements landscape count
	var rm_ls := state.remove_card_by_id("ls_volcanic_ridge")
	_check(rm_ls, "remove_card_by_id removed one landscape card")
	_check(state.landscape_deck.size() == 7, "Landscape sub-deck size decremented to 7")
	_check(state.main_deck.size() == 30, "Main deck size unchanged at 30 when removing landscape")

func _test_validation_rules() -> void:
	var ignis := CardDatabase.get_hero("hr_ignis")
	var state := DeckBuildState.new(ignis)

	# Test 7: Deck validation reports valid only when main deck has 30 cards and landscape deck has 5-8 cards
	_check(not state.is_valid(), "Empty deck is invalid")
	var initial_errors := state.get_validation_errors()
	_check(initial_errors.size() >= 2, "Validation lists main deck and landscape deck errors on empty deck")

	# Add 30 main cards
	for i in range(10):
		var dummy := _create_dummy_card("valid_main_%d" % i, "Valid Main %d" % i, false, "fire")
		for c in range(3):
			state.add_card(dummy)

	_check(state.main_deck.size() == 30, "Main deck filled to 30 cards")
	_check(not state.is_valid(), "Deck with 30 main cards and 0 landscape cards is invalid")

	# Add 4 landscape cards (below min of 5)
	var ls_1 := _create_dummy_card("valid_ls_1", "Valid LS 1", true, "fire")
	var ls_2 := _create_dummy_card("valid_ls_2", "Valid LS 2", true, "fire")
	state.add_card(ls_1)
	state.add_card(ls_1)
	state.add_card(ls_2)
	state.add_card(ls_2)
	_check(state.landscape_deck.size() == 4, "Landscape deck has 4 cards")
	_check(not state.is_valid(), "Deck with 4 landscape cards is invalid (minimum is 5)")

	# Add 5th landscape card -> Now valid (30 main, 5 landscape)
	state.add_card(ls_2)
	_check(state.landscape_deck.size() == 5, "Landscape deck has 5 cards")
	_check(state.is_valid(), "Deck with 30 main cards and 5 landscape cards is VALID")
	_check(state.get_validation_errors().is_empty(), "Validation error list is empty when valid")

	# Add up to 8 landscape cards -> Still valid
	var ls_3 := _create_dummy_card("valid_ls_3", "Valid LS 3", true, "fire")
	state.add_card(ls_3)
	state.add_card(ls_3)
	state.add_card(ls_3)
	_check(state.landscape_deck.size() == 8, "Landscape deck has 8 cards")
	_check(state.is_valid(), "Deck with 30 main cards and 8 landscape cards is VALID")

	# Affinity mismatch validation
	var water_card := _create_dummy_card("water_card", "Water Card", false, "water")
	_check(not state.can_add_card(water_card), "Cannot add water card to fire hero deck")
	_check(state.get_add_card_error(water_card) == "affinity_mismatch", "Error code is affinity_mismatch")

func _test_deck_builder_ui() -> void:
	var deck_builder := DeckBuilderScene.instantiate() as DeckBuilder
	_check(deck_builder != null, "DeckBuilder scene instantiated")
	add_child(deck_builder)

	var ignis := CardDatabase.get_hero("hr_ignis")
	deck_builder.select_hero(ignis)
	_check(deck_builder.deck_state.hero == ignis, "DeckBuilder selected Ignis")
	_check(deck_builder.hero_name_label.text == "Ignis", "HeroNameLabel displays Ignis")

	# Check eligible card grid is populated
	var eligible_count := CardDatabase.get_eligible_cards_for_hero(ignis).size()
	var grid_child_count := deck_builder.card_grid.get_child_count()
	_check(grid_child_count == eligible_count, "Card grid populated with %d eligible cards (got %d)" % [eligible_count, grid_child_count])

	# Test 8: DeckBuilder UI wires correctly to deck state and updates counts upon adding/removing
	_check(deck_builder.main_deck_count_label.text == "Main Deck: 0 / 30", "Initial main deck count label is 'Main Deck: 0 / 30'")
	_check(deck_builder.landscape_deck_count_label.text == "Landscape Deck: 0 / 8 (min 5)", "Initial landscape count label is 'Landscape Deck: 0 / 8 (min 5)'")

	var added_creature := deck_builder.add_card_by_id("cr_flame_drake")
	_check(added_creature, "Added cr_flame_drake via DeckBuilder API")
	_check(deck_builder.deck_state.main_deck.size() == 1, "Deck state main deck size is 1")
	_check(deck_builder.main_deck_count_label.text == "Main Deck: 1 / 30", "Main deck count label updated to 'Main Deck: 1 / 30'")
	_check(deck_builder.main_deck_container.get_child_count() == 1, "Main deck list has 1 entry row")

	var added_landscape := deck_builder.add_card_by_id("ls_volcanic_ridge")
	_check(added_landscape, "Added ls_volcanic_ridge via DeckBuilder API")
	_check(deck_builder.deck_state.landscape_deck.size() == 1, "Deck state landscape deck size is 1")
	_check(deck_builder.landscape_deck_count_label.text == "Landscape Deck: 1 / 8 (min 5)", "Landscape count label updated to 'Landscape Deck: 1 / 8 (min 5)'")
	_check(deck_builder.landscape_deck_container.get_child_count() == 1, "Landscape deck list has 1 entry row")

	# Remove main deck card
	var removed_creature := deck_builder.remove_card_by_id("cr_flame_drake")
	_check(removed_creature, "Removed cr_flame_drake via DeckBuilder API")
	_check(deck_builder.deck_state.main_deck.is_empty(), "Deck state main deck is now empty")
	_check(deck_builder.main_deck_count_label.text == "Main Deck: 0 / 30", "Main deck count label updated back to 'Main Deck: 0 / 30'")
	_check(deck_builder.main_deck_container.get_child_count() == 0, "Main deck list has 0 entry rows")

	# Remove landscape card
	var removed_landscape := deck_builder.remove_card_by_id("ls_volcanic_ridge")
	_check(removed_landscape, "Removed ls_volcanic_ridge via DeckBuilder API")
	_check(deck_builder.deck_state.landscape_deck.is_empty(), "Deck state landscape deck is now empty")
	_check(deck_builder.landscape_deck_count_label.text == "Landscape Deck: 0 / 8 (min 5)", "Landscape count label updated back to 'Landscape Deck: 0 / 8 (min 5)'")
	_check(deck_builder.landscape_deck_container.get_child_count() == 0, "Landscape deck list has 0 entry rows")

	# Test clear button
	deck_builder.add_card_by_id("cr_flame_drake")
	deck_builder.add_card_by_id("ls_volcanic_ridge")
	_check(deck_builder.deck_state.main_deck.size() == 1, "Main deck has 1 card before clear")
	_check(deck_builder.deck_state.landscape_deck.size() == 1, "Landscape deck has 1 card before clear")
	deck_builder.clear_deck()
	_check(deck_builder.deck_state.main_deck.is_empty(), "Main deck empty after clear_deck()")
	_check(deck_builder.deck_state.landscape_deck.is_empty(), "Landscape deck empty after clear_deck()")

	remove_child(deck_builder)
	deck_builder.queue_free()

func _test_manual_aspects() -> void:
	_manual_check("Card grid responsive layout, column wrapping, and card display item visual presentation")
	_manual_check("Scroll behavior for eligible card pool and deck list panels")
	_manual_check("Button hover and disabled visual cues when limits (30 main, 8 landscape, 3 copies) are reached")
