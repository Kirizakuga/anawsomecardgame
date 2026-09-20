class_name LaneView
extends PanelContainer

signal card_dropped_in_lane(card_view: CardView, lane_index: int)

@export var lane_index: int = 0
@export var card_slot: CenterContainer

var current_card_view: CardView = null
var kingdom_view: KingdomView = null

func _ready() -> void:
	custom_minimum_size = Vector2(110, 150)
	if not card_slot:
		card_slot = get_node_or_null("CenterContainer")

func set_occupant(card: CardResource) -> void:
	if current_card_view:
		if current_card_view.get_parent():
			current_card_view.get_parent().remove_child(current_card_view)
		current_card_view.queue_free()
		current_card_view = null

	if card:
		var cv_scene: PackedScene = load("res://scenes/match/CardView.tscn")
		current_card_view = cv_scene.instantiate()
		current_card_view.card_data = card
		card_slot.add_child(current_card_view)
		if kingdom_view and kingdom_view.has_method("_connect_card_view_floop"):
			kingdom_view._connect_card_view_floop(current_card_view)

func is_occupied() -> bool:
	return current_card_view != null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_occupied():
		return false
	if not (data is Dictionary and data.get("type") == "card"):
		return false
	var card_data: CardResource = data.get("card_data")
	if not (card_data is CreatureResource):
		return false
	if kingdom_view and kingdom_view.kingdom_state:
		if kingdom_view.kingdom_state.essence < card_data.essence_cost:
			return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary and data.get("type") == "card"):
		return
	var source_view: CardView = data.get("source_view") as CardView
	if not source_view:
		return
	if source_view.get_parent():
		source_view.get_parent().remove_child(source_view)
	current_card_view = source_view
	card_slot.add_child(current_card_view)
	card_dropped_in_lane.emit(current_card_view, lane_index)
