extends Node

var cards: Dictionary = {}

func _ready() -> void:
	load_all_cards("res://data/cards/")

func load_all_cards(base_path: String) -> void:
	cards.clear()
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
			var card_res: CardResource = load(full_path) as CardResource
			if card_res and card_res.id != "":
				if cards.has(card_res.id):
					push_warning("CardDatabase: Duplicate card id '%s' at %s" % [card_res.id, full_path])
				cards[card_res.id] = card_res
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
