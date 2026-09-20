class_name DeckSaveManager
extends RefCounted

# ponytail: simple single-profile local JSON deck save/load. Upgrade to multi-deck / profile slots when profile UI arrives.

const DEFAULT_SAVE_PATH: String = "user://saved_deck.json"

static func save_deck_to_file(deck_state: DeckBuildState, path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if deck_state == null:
		return {"success": false, "error": "DeckBuildState is null."}

	var json_str := deck_state.to_json()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		return {"success": false, "error": "Failed to open file for writing at %s (error code: %d)" % [path, err]}

	file.store_string(json_str)
	file.close()

	return {"success": true, "error": "", "path": path}

static func load_deck_from_file(deck_state: DeckBuildState, path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if deck_state == null:
		return {"success": false, "error": "DeckBuildState is null.", "missing_ids": []}

	if not FileAccess.file_exists(path):
		return {"success": false, "error": "Save file does not exist at %s" % path, "missing_ids": []}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		return {"success": false, "error": "Failed to open file for reading at %s (error code: %d)" % [path, err], "missing_ids": []}

	var json_text := file.get_as_text()
	file.close()

	var res := deck_state.load_from_json(json_text)
	res["path"] = path
	return res
