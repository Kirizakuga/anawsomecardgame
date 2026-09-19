class_name DeckBuildState
extends RefCounted

signal deck_changed()
signal card_added(card: CardResource, is_landscape: bool)
signal card_removed(card: CardResource, is_landscape: bool)
signal hero_changed(new_hero: HeroResource)

const MAX_MAIN_DECK_SIZE: int = 30
const MAX_COPIES_PER_CARD: int = 3
const MIN_LANDSCAPE_DECK_SIZE: int = 5
const MAX_LANDSCAPE_DECK_SIZE: int = 8

var hero: HeroResource = null
var main_deck: Array[CardResource] = []
var landscape_deck: Array[CardResource] = []

func _init(p_hero: HeroResource = null) -> void:
	hero = p_hero

func set_hero(p_hero: HeroResource, clear_incompatible: bool = false) -> void:
	hero = p_hero
	if clear_incompatible and hero != null:
		var new_main: Array[CardResource] = []
		for c in main_deck:
			if is_card_affinity_compatible(c, hero.affinity):
				new_main.append(c)
		main_deck = new_main

		var new_landscape: Array[CardResource] = []
		for c in landscape_deck:
			if is_card_affinity_compatible(c, hero.affinity):
				new_landscape.append(c)
		landscape_deck = new_landscape

	hero_changed.emit(hero)
	deck_changed.emit()

static func is_card_affinity_compatible(card: CardResource, hero_affinity: String) -> bool:
	if not card:
		return false
	var target_affinity := hero_affinity.to_lower().strip_edges()
	if target_affinity == "":
		return true

	if card is CreatureResource:
		var aff := (card as CreatureResource).affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif card is SpellResource:
		var aff := (card as SpellResource).affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif card is LandscapeResource:
		var aff := (card as LandscapeResource).affected_affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif "affinity" in card:
		var aff: String = str(card.get("affinity")).to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	return true

func get_card_count(card_id: String) -> int:
	var count := 0
	for card in main_deck:
		if card.id == card_id:
			count += 1
	for card in landscape_deck:
		if card.id == card_id:
			count += 1
	return count

func get_main_deck_count(card_id: String) -> int:
	var count := 0
	for card in main_deck:
		if card.id == card_id:
			count += 1
	return count

func get_landscape_deck_count(card_id: String) -> int:
	var count := 0
	for card in landscape_deck:
		if card.id == card_id:
			count += 1
	return count

func can_add_card(card: CardResource) -> bool:
	return get_add_card_error(card) == ""

func get_add_card_error(card: CardResource) -> String:
	if card == null or card.id == "":
		return "invalid_card"

	if hero != null and not is_card_affinity_compatible(card, hero.affinity):
		return "affinity_mismatch"

	if get_card_count(card.id) >= MAX_COPIES_PER_CARD:
		return "max_copies_reached"

	if card is LandscapeResource:
		if landscape_deck.size() >= MAX_LANDSCAPE_DECK_SIZE:
			return "landscape_deck_full"
	else:
		if main_deck.size() >= MAX_MAIN_DECK_SIZE:
			return "main_deck_full"

	return ""

func add_card(card: CardResource) -> bool:
	if not can_add_card(card):
		return false

	var is_landscape := (card is LandscapeResource)
	if is_landscape:
		landscape_deck.append(card)
	else:
		main_deck.append(card)

	card_added.emit(card, is_landscape)
	deck_changed.emit()
	return true

func remove_card(card: CardResource) -> bool:
	if card == null:
		return false
	return remove_card_by_id(card.id)

func remove_card_by_id(card_id: String) -> bool:
	if remove_main_deck_card_by_id(card_id):
		return true
	return remove_landscape_card_by_id(card_id)

func remove_main_deck_card_by_id(card_id: String) -> bool:
	for i in range(main_deck.size()):
		if main_deck[i].id == card_id:
			var removed_card: CardResource = main_deck[i]
			main_deck.remove_at(i)
			card_removed.emit(removed_card, false)
			deck_changed.emit()
			return true
	return false

func remove_landscape_card_by_id(card_id: String) -> bool:
	for i in range(landscape_deck.size()):
		if landscape_deck[i].id == card_id:
			var removed_card: CardResource = landscape_deck[i]
			landscape_deck.remove_at(i)
			card_removed.emit(removed_card, true)
			deck_changed.emit()
			return true
	return false

func clear() -> void:
	main_deck.clear()
	landscape_deck.clear()
	deck_changed.emit()

func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	if hero == null:
		errors.append("No Hero selected.")

	if main_deck.size() != MAX_MAIN_DECK_SIZE:
		errors.append("Main deck must have exactly %d cards (currently %d)." % [MAX_MAIN_DECK_SIZE, main_deck.size()])

	if landscape_deck.size() < MIN_LANDSCAPE_DECK_SIZE or landscape_deck.size() > MAX_LANDSCAPE_DECK_SIZE:
		errors.append("Landscape deck must have between %d and %d cards (currently %d)." % [MIN_LANDSCAPE_DECK_SIZE, MAX_LANDSCAPE_DECK_SIZE, landscape_deck.size()])

	var counts: Dictionary = {}
	for card in main_deck:
		counts[card.id] = counts.get(card.id, 0) + 1
	for card in landscape_deck:
		counts[card.id] = counts.get(card.id, 0) + 1

	for card_id in counts.keys():
		if counts[card_id] > MAX_COPIES_PER_CARD:
			errors.append("Card '%s' exceeds max limit of %d copies (currently %d)." % [card_id, MAX_COPIES_PER_CARD, counts[card_id]])

	for card in main_deck:
		if card is LandscapeResource:
			errors.append("Landscape card '%s' cannot be placed in main deck." % card.display_name)
			break

	for card in landscape_deck:
		if not (card is LandscapeResource):
			errors.append("Non-landscape card '%s' cannot be placed in landscape deck." % card.display_name)
			break

	if hero != null:
		for card in main_deck:
			if not is_card_affinity_compatible(card, hero.affinity):
				errors.append("Card '%s' is not compatible with Hero affinity '%s'." % [card.display_name, hero.affinity])
				break
		for card in landscape_deck:
			if not is_card_affinity_compatible(card, hero.affinity):
				errors.append("Landscape '%s' is not compatible with Hero affinity '%s'." % [card.display_name, hero.affinity])
				break

	return errors

func is_valid() -> bool:
	return get_validation_errors().is_empty()
