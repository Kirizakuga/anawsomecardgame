extends Node

var cards: Dictionary = {}
var heroes: Dictionary = {}

func _ready() -> void:
	load_all_cards("res://data/cards/")

func load_all_cards(base_path: String) -> void:
	cards.clear()
	heroes.clear()
	_scan_dir(base_path)

func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("CardDatabase: Failed to open directory %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_dir(full_path)
		elif file_name.ends_with(".tres"):
			var res: Resource = load(full_path)
			if res is CardResource and res.id != "":
				if cards.has(res.id):
					push_warning("CardDatabase: Duplicate card id '%s' at %s" % [res.id, full_path])
				cards[res.id] = res
			elif res is HeroResource and res.id != "":
				if heroes.has(res.id):
					push_warning("CardDatabase: Duplicate hero id '%s' at %s" % [res.id, full_path])
				heroes[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func get_card(id: String) -> CardResource:
	return cards.get(id, null)

func has_card(id: String) -> bool:
	return cards.has(id)

func get_all_cards() -> Array[CardResource]:
	var result: Array[CardResource] = []
	for card in cards.values():
		result.append(card)
	return result

func get_hero(id: String) -> HeroResource:
	return heroes.get(id, null)

func has_hero(id: String) -> bool:
	return heroes.has(id)

func get_all_heroes() -> Array[HeroResource]:
	var result: Array[HeroResource] = []
	for hero in heroes.values():
		result.append(hero)
	return result

func is_card_eligible_for_affinity(card: CardResource, hero_affinity: String) -> bool:
	if not card:
		return false
	var target_affinity := hero_affinity.to_lower().strip_edges()
	if card is CreatureResource:
		var creature := card as CreatureResource
		var aff := creature.affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif card is SpellResource:
		var spell := card as SpellResource
		var aff := spell.affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif card is LandscapeResource:
		var landscape := card as LandscapeResource
		var aff := landscape.affected_affinity.to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	elif "affinity" in card:
		var aff: String = str(card.get("affinity")).to_lower().strip_edges()
		return aff == "" or aff == target_affinity
	return true

func get_cards_by_affinity(affinity: String) -> Array[CardResource]:
	var result: Array[CardResource] = []
	for card in cards.values():
		if is_card_eligible_for_affinity(card, affinity):
			result.append(card)
	return result

func get_eligible_cards_for_hero(hero: HeroResource) -> Array[CardResource]:
	if not hero:
		return []
	return get_cards_by_affinity(hero.affinity)
