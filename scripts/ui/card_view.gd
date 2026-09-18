@tool
class_name CardView
extends Control

signal card_clicked(card_view: CardView)
signal floop_triggered(card_view: CardView)

@export var card_data: CardResource:
	set(value):
		card_data = value
		update_view()

@export var is_flooped: bool = false:
	set(value):
		is_flooped = value
		_update_floop_state()

@onready var background: ColorRect = get_node_or_null("Background")
@onready var art_rect: TextureRect = get_node_or_null("ArtRect")
@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var cost_label: Label = get_node_or_null("CostLabel")
@onready var attack_label: Label = get_node_or_null("AttackLabel")
@onready var defense_label: Label = get_node_or_null("DefenseLabel")
@onready var floop_button: Button = get_node_or_null("FloopButton")

func _ready() -> void:
	_update_pivot()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if floop_button and not Engine.is_editor_hint():
		floop_button.pressed.connect(_on_floop_pressed)
	update_view()

func _update_pivot() -> void:
	var target_size := size if size != Vector2.ZERO else custom_minimum_size
	pivot_offset = target_size / 2.0

func update_view() -> void:
	if not is_inside_tree():
		return

	visible = true

	if not card_data:
		if art_rect:
			art_rect.texture = null
		if name_label:
			name_label.text = "Card Name"
		if cost_label:
			cost_label.text = "0"
		if attack_label:
			attack_label.visible = true
			attack_label.text = "ATK: 0"
		if defense_label:
			defense_label.visible = true
			defense_label.text = "DEF: 0"
		if floop_button:
			floop_button.visible = true
		_update_floop_state()
		return

	if name_label:
		name_label.text = card_data.display_name
	if cost_label:
		cost_label.text = str(card_data.essence_cost)
	if art_rect:
		art_rect.texture = card_data.art if card_data.art else null

	if card_data is CreatureResource:
		var creature := card_data as CreatureResource
		if attack_label:
			attack_label.visible = true
			attack_label.text = "ATK: %d" % creature.attack
		if defense_label:
			defense_label.visible = true
			defense_label.text = "DEF: %d" % creature.defense
	else:
		if attack_label:
			attack_label.visible = false
		if defense_label:
			defense_label.visible = false

	if floop_button:
		floop_button.visible = card_data.floop_effect != null

	_update_floop_state()

func _update_floop_state() -> void:
	if not is_inside_tree():
		return
	_update_pivot()
	# ponytail: simple 90-degree visual turn; upgrade with Tween animation in M5-04 juice pass
	rotation_degrees = 90.0 if is_flooped else 0.0

func _on_floop_pressed() -> void:
	is_flooped = not is_flooped
	floop_triggered.emit(self)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if Engine.is_editor_hint():
		return null
	var preview := Label.new()
	preview.text = card_data.display_name if card_data else "Card"
	set_drag_preview(preview)
	# ponytail: simple alpha dimming and restore for snapback; upgrade with bounce Tween in M5-04 juice pass
	modulate.a = 0.5
	return {"type": "card", "card_data": card_data, "source_view": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
