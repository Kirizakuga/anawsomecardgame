class_name HeroSelect
extends Control

signal hero_selected(hero: HeroResource, eligible_cards: Array[CardResource])

@export var hero_container_path: NodePath = "VBoxContainer/HeroContainer"
@export var details_name_label_path: NodePath = "VBoxContainer/DetailsPanel/MarginContainer/VBoxContainer/DetailsName"
@export var details_trait_label_path: NodePath = "VBoxContainer/DetailsPanel/MarginContainer/VBoxContainer/DetailsTrait"
@export var details_cards_label_path: NodePath = "VBoxContainer/DetailsPanel/MarginContainer/VBoxContainer/DetailsCards"

var selected_hero: HeroResource = null
var selected_eligible_cards: Array[CardResource] = []
var hero_buttons: Dictionary = {}

@onready var hero_container: Container = get_node_or_null(hero_container_path) as Container
@onready var details_name_label: Label = get_node_or_null(details_name_label_path) as Label
@onready var details_trait_label: Label = get_node_or_null(details_trait_label_path) as Label
@onready var details_cards_label: Label = get_node_or_null(details_cards_label_path) as Label

func _ready() -> void:
	if not Engine.is_editor_hint():
		populate_heroes()

func populate_heroes(hero_list: Array[HeroResource] = []) -> void:
	if not hero_container:
		hero_container = get_node_or_null(hero_container_path) as Container
		if not hero_container:
			return

	for child in hero_container.get_children():
		hero_container.remove_child(child)
		child.queue_free()
	hero_buttons.clear()

	var heroes_to_show: Array[HeroResource] = hero_list
	if heroes_to_show.is_empty():
		heroes_to_show = CardDatabase.get_all_heroes()

	heroes_to_show.sort_custom(func(a: HeroResource, b: HeroResource) -> bool:
		return a.id < b.id
	)

	for hero in heroes_to_show:
		var card := _create_hero_card(hero)
		hero_container.add_child(card)

func _create_hero_card(hero: HeroResource) -> Control:
	var panel := PanelContainer.new()
	panel.name = "HeroCard_%s" % hero.id
	panel.custom_minimum_size = Vector2(220, 280)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var portrait_rect := TextureRect.new()
	portrait_rect.name = "PortraitRect"
	portrait_rect.custom_minimum_size = Vector2(100, 100)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if hero.portrait:
		portrait_rect.texture = hero.portrait
	vbox.add_child(portrait_rect)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = hero.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var affinity_lbl := Label.new()
	affinity_lbl.name = "AffinityLabel"
	affinity_lbl.text = "Affinity: %s" % hero.affinity.capitalize()
	affinity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(affinity_lbl)

	var trait_lbl := Label.new()
	trait_lbl.name = "TraitLabel"
	trait_lbl.text = hero.passive_trait
	trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(trait_lbl)

	var btn := Button.new()
	btn.name = "SelectButton"
	btn.text = "Select %s" % hero.display_name
	btn.pressed.connect(func(): select_hero(hero))
	vbox.add_child(btn)

	hero_buttons[hero.id] = btn
	return panel

func select_hero_by_id(hero_id: String) -> void:
	var hero := CardDatabase.get_hero(hero_id)
	if hero:
		select_hero(hero)
	else:
		push_error("HeroSelect: Hero with id '%s' not found" % hero_id)

func select_hero(hero: HeroResource) -> void:
	if not hero:
		return
	selected_hero = hero
	selected_eligible_cards = CardDatabase.get_eligible_cards_for_hero(hero)

	_update_details_view()
	_update_button_states()

	hero_selected.emit(selected_hero, selected_eligible_cards)

func _update_details_view() -> void:
	if not details_name_label:
		details_name_label = get_node_or_null(details_name_label_path) as Label
	if not details_trait_label:
		details_trait_label = get_node_or_null(details_trait_label_path) as Label
	if not details_cards_label:
		details_cards_label = get_node_or_null(details_cards_label_path) as Label

	if selected_hero:
		if details_name_label:
			details_name_label.text = "%s (%s)" % [selected_hero.display_name, selected_hero.affinity.capitalize()]
		if details_trait_label:
			details_trait_label.text = selected_hero.passive_trait
		if details_cards_label:
			var card_names: Array[String] = []
			for c in selected_eligible_cards:
				card_names.append(c.display_name)
			details_cards_label.text = "Eligible Cards (%d): %s" % [selected_eligible_cards.size(), ", ".join(card_names)]

func _update_button_states() -> void:
	for h_id in hero_buttons.keys():
		var btn: Button = hero_buttons[h_id]
		if is_instance_valid(btn):
			if selected_hero and selected_hero.id == h_id:
				btn.text = "Selected"
				btn.disabled = true
			else:
				var h: HeroResource = CardDatabase.get_hero(h_id)
				var d_name: String = h.display_name if h != null else h_id
				btn.text = "Select %s" % d_name
				btn.disabled = false
