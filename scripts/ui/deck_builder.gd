class_name DeckBuilder
extends Control

signal deck_modified(deck_state: DeckBuildState)
signal hero_selected(hero: HeroResource)
signal validation_changed(is_valid: bool)

@export var hero_name_label_path: NodePath = "MainLayout/TopBar/HeroInfo/HeroNameLabel"
@export var hero_affinity_label_path: NodePath = "MainLayout/TopBar/HeroInfo/HeroAffinityLabel"
@export var hero_trait_label_path: NodePath = "MainLayout/TopBar/HeroInfo/HeroTraitLabel"
@export var hero_option_button_path: NodePath = "MainLayout/TopBar/HeroSelector/HeroOptionButton"

@export var main_deck_count_label_path: NodePath = "MainLayout/BodyLayout/RightPanel/MainDeckSection/Header/MainDeckCountLabel"
@export var main_deck_container_path: NodePath = "MainLayout/BodyLayout/RightPanel/MainDeckSection/ScrollContainer/MainDeckList"

@export var landscape_deck_count_label_path: NodePath = "MainLayout/BodyLayout/RightPanel/LandscapeSection/Header/LandscapeCountLabel"
@export var landscape_deck_container_path: NodePath = "MainLayout/BodyLayout/RightPanel/LandscapeSection/ScrollContainer/LandscapeList"

@export var card_grid_path: NodePath = "MainLayout/BodyLayout/LeftPanel/ScrollContainer/CardGrid"
@export var validation_label_path: NodePath = "MainLayout/TopBar/DeckStatus/ValidationLabel"
@export var done_button_path: NodePath = "MainLayout/TopBar/DeckStatus/DoneButton"
@export var clear_button_path: NodePath = "MainLayout/BodyLayout/RightPanel/BottomControls/ClearButton"

var deck_state: DeckBuildState
var current_filter: String = "all"
var available_heroes: Array[HeroResource] = []

@onready var hero_name_label: Label = get_node_or_null(hero_name_label_path) as Label
@onready var hero_affinity_label: Label = get_node_or_null(hero_affinity_label_path) as Label
@onready var hero_trait_label: Label = get_node_or_null(hero_trait_label_path) as Label
@onready var hero_option_button: OptionButton = get_node_or_null(hero_option_button_path) as OptionButton

@onready var main_deck_count_label: Label = get_node_or_null(main_deck_count_label_path) as Label
@onready var main_deck_container: Container = get_node_or_null(main_deck_container_path) as Container

@onready var landscape_deck_count_label: Label = get_node_or_null(landscape_deck_count_label_path) as Label
@onready var landscape_deck_container: Container = get_node_or_null(landscape_deck_container_path) as Container

@onready var card_grid: Container = get_node_or_null(card_grid_path) as Container
@onready var validation_label: Label = get_node_or_null(validation_label_path) as Label
@onready var done_button: Button = get_node_or_null(done_button_path) as Button
@onready var clear_button: Button = get_node_or_null(clear_button_path) as Button

func _ready() -> void:
	if not deck_state:
		deck_state = DeckBuildState.new()
	deck_state.deck_changed.connect(_on_deck_changed)

	_bind_ui_nodes()
	_setup_hero_selector()

	if deck_state.hero == null and not available_heroes.is_empty():
		select_hero(available_heroes[0])
	else:
		refresh_ui()

func _bind_ui_nodes() -> void:
	if not hero_name_label:
		hero_name_label = get_node_or_null(hero_name_label_path) as Label
	if not hero_affinity_label:
		hero_affinity_label = get_node_or_null(hero_affinity_label_path) as Label
	if not hero_trait_label:
		hero_trait_label = get_node_or_null(hero_trait_label_path) as Label
	if not hero_option_button:
		hero_option_button = get_node_or_null(hero_option_button_path) as OptionButton

	if not main_deck_count_label:
		main_deck_count_label = get_node_or_null(main_deck_count_label_path) as Label
	if not main_deck_container:
		main_deck_container = get_node_or_null(main_deck_container_path) as Container

	if not landscape_deck_count_label:
		landscape_deck_count_label = get_node_or_null(landscape_deck_count_label_path) as Label
	if not landscape_deck_container:
		landscape_deck_container = get_node_or_null(landscape_deck_container_path) as Container

	if not card_grid:
		card_grid = get_node_or_null(card_grid_path) as Container
	if not validation_label:
		validation_label = get_node_or_null(validation_label_path) as Label
	if not done_button:
		done_button = get_node_or_null(done_button_path) as Button
	if not clear_button:
		clear_button = get_node_or_null(clear_button_path) as Button

	if clear_button and not clear_button.pressed.is_connected(clear_deck):
		clear_button.pressed.connect(clear_deck)

func _setup_hero_selector() -> void:
	available_heroes = CardDatabase.get_all_heroes()
	available_heroes.sort_custom(func(a: HeroResource, b: HeroResource) -> bool:
		return a.id < b.id
	)
	if hero_option_button:
		hero_option_button.clear()
		for i in range(available_heroes.size()):
			var h := available_heroes[i]
			hero_option_button.add_item("%s (%s)" % [h.display_name, h.affinity.capitalize()], i)
		if not hero_option_button.item_selected.is_connected(_on_hero_option_selected):
			hero_option_button.item_selected.connect(_on_hero_option_selected)

func _on_hero_option_selected(index: int) -> void:
	if index >= 0 and index < available_heroes.size():
		select_hero(available_heroes[index])

func select_hero(hero: HeroResource) -> void:
	if not deck_state:
		deck_state = DeckBuildState.new()
	deck_state.set_hero(hero, true)

	if hero_option_button:
		for i in range(available_heroes.size()):
			if available_heroes[i].id == hero.id:
				hero_option_button.select(i)
				break

	hero_selected.emit(hero)
	refresh_ui()

func set_filter(filter_name: String) -> void:
	current_filter = filter_name.to_lower()
	_populate_card_grid()

func clear_deck() -> void:
	if deck_state:
		deck_state.clear()

func add_card_by_id(card_id: String) -> bool:
	var card := CardDatabase.get_card(card_id)
	if not card:
		return false
	return add_card(card)

func add_card(card: CardResource) -> bool:
	if not deck_state:
		return false
	return deck_state.add_card(card)

func remove_card_by_id(card_id: String) -> bool:
	if not deck_state:
		return false
	return deck_state.remove_card_by_id(card_id)

func _on_deck_changed() -> void:
	refresh_ui()
	deck_modified.emit(deck_state)
	validation_changed.emit(deck_state.is_valid())

func refresh_ui() -> void:
	_bind_ui_nodes()
	_update_hero_display()
	_update_deck_counts()
	_update_validation_status()
	_populate_card_grid()
	_populate_deck_lists()

func _update_hero_display() -> void:
	if not deck_state or not deck_state.hero:
		if hero_name_label:
			hero_name_label.text = "No Hero Selected"
		if hero_affinity_label:
			hero_affinity_label.text = ""
		if hero_trait_label:
			hero_trait_label.text = ""
		return

	var h := deck_state.hero
	if hero_name_label:
		hero_name_label.text = h.display_name
	if hero_affinity_label:
		hero_affinity_label.text = "Affinity: %s | Life: %d" % [h.affinity.capitalize(), h.starting_life]
	if hero_trait_label:
		hero_trait_label.text = h.passive_trait

func _update_deck_counts() -> void:
	if not deck_state:
		return

	if main_deck_count_label:
		main_deck_count_label.text = "Main Deck: %d / %d" % [deck_state.main_deck.size(), DeckBuildState.MAX_MAIN_DECK_SIZE]
	if landscape_deck_count_label:
		landscape_deck_count_label.text = "Landscape Deck: %d / %d (min %d)" % [
			deck_state.landscape_deck.size(),
			DeckBuildState.MAX_LANDSCAPE_DECK_SIZE,
			DeckBuildState.MIN_LANDSCAPE_DECK_SIZE
		]

func _update_validation_status() -> void:
	if not deck_state:
		return

	var is_valid := deck_state.is_valid()
	var errors := deck_state.get_validation_errors()

	if validation_label:
		if is_valid:
			validation_label.text = "[ DECK READY ]"
			validation_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			validation_label.text = "[ NOT READY: %s ]" % errors[0] if not errors.is_empty() else "[ INVALID ]"
			validation_label.modulate = Color(1.0, 0.4, 0.3)

	if done_button:
		done_button.disabled = not is_valid

func _populate_card_grid() -> void:
	if not card_grid:
		return

	for child in card_grid.get_children():
		card_grid.remove_child(child)
		child.queue_free()

	if not deck_state or not deck_state.hero:
		return

	var eligible := CardDatabase.get_eligible_cards_for_hero(deck_state.hero)
	eligible.sort_custom(func(a: CardResource, b: CardResource) -> bool:
		if a.essence_cost != b.essence_cost:
			return a.essence_cost < b.essence_cost
		return a.id < b.id
	)

	for card in eligible:
		if not _matches_filter(card):
			continue
		var card_item := _create_grid_card_item(card)
		card_grid.add_child(card_item)

func _matches_filter(card: CardResource) -> bool:
	if current_filter == "all":
		return true
	elif current_filter == "creature":
		return card is CreatureResource
	elif current_filter == "spell":
		return card is SpellResource
	elif current_filter == "landscape":
		return card is LandscapeResource
	return true

func _create_grid_card_item(card: CardResource) -> Control:
	var panel := PanelContainer.new()
	panel.name = "GridCard_%s" % card.id
	panel.custom_minimum_size = Vector2(170, 150)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Name & Cost
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "%s (%d)" % [card.display_name, card.essence_cost]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Type & Stats
	var type_lbl := Label.new()
	type_lbl.name = "TypeLabel"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if card is CreatureResource:
		var c := card as CreatureResource
		type_lbl.text = "Creature | %d/%d" % [c.attack, c.defense]
	elif card is SpellResource:
		type_lbl.text = "Spell"
	elif card is LandscapeResource:
		type_lbl.text = "Landscape"
	else:
		type_lbl.text = "Card"
	vbox.add_child(type_lbl)

	# Deck count
	var count := deck_state.get_card_count(card.id)
	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.text = "In Deck: %d / %d" % [count, DeckBuildState.MAX_COPIES_PER_CARD]
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_lbl)

	# Add Button
	var add_btn := Button.new()
	add_btn.name = "AddButton"
	add_btn.text = "+ Add to Deck"
	var can_add := deck_state.can_add_card(card)
	add_btn.disabled = not can_add
	add_btn.pressed.connect(func(): add_card(card))
	vbox.add_child(add_btn)

	return panel

func _populate_deck_lists() -> void:
	if not deck_state:
		return

	# Main deck list
	if main_deck_container:
		for child in main_deck_container.get_children():
			main_deck_container.remove_child(child)
			child.queue_free()

		var main_counts := _get_grouped_deck_entries(deck_state.main_deck)
		for entry in main_counts:
			var row := _create_deck_list_row(entry["card"], entry["count"], false)
			main_deck_container.add_child(row)

	# Landscape deck list
	if landscape_deck_container:
		for child in landscape_deck_container.get_children():
			landscape_deck_container.remove_child(child)
			child.queue_free()

		var landscape_counts := _get_grouped_deck_entries(deck_state.landscape_deck)
		for entry in landscape_counts:
			var row := _create_deck_list_row(entry["card"], entry["count"], true)
			landscape_deck_container.add_child(row)

func _get_grouped_deck_entries(deck_array: Array[CardResource]) -> Array[Dictionary]:
	var map: Dictionary = {}
	var order: Array[String] = []

	for card in deck_array:
		if not map.has(card.id):
			map[card.id] = {"card": card, "count": 1}
			order.append(card.id)
		else:
			map[card.id]["count"] += 1

	var result: Array[Dictionary] = []
	for id in order:
		result.append(map[id])
	return result

func _create_deck_list_row(card: CardResource, count: int, is_landscape: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "DeckRow_%s" % card.id

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var label := Label.new()
	label.name = "CardLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_str := " [Landscape]" if is_landscape else " (%d)" % card.essence_cost
	label.text = "%s%s x%d" % [card.display_name, type_str, count]
	hbox.add_child(label)

	var remove_btn := Button.new()
	remove_btn.name = "RemoveButton"
	remove_btn.text = " - "
	remove_btn.pressed.connect(func(): deck_state.remove_card_by_id(card.id))
	hbox.add_child(remove_btn)

	var add_btn := Button.new()
	add_btn.name = "AddButton"
	add_btn.text = " + "
	add_btn.disabled = not deck_state.can_add_card(card)
	add_btn.pressed.connect(func(): deck_state.add_card(card))
	hbox.add_child(add_btn)

	return panel
