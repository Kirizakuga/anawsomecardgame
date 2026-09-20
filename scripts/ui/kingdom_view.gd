class_name KingdomView
extends VBoxContainer

signal card_play_requested(card: CardResource, lane_index: int)

@export var is_human: bool = false

@onready var life_label: Label = $Header/LifeLabel
@onready var lanes_container: HBoxContainer = $LanesContainer
@onready var hand_view: HandView = $HandView

var lane_views: Array[LaneView] = []
var kingdom_state: KingdomState = null
var decision_source: HumanDecisionSource = null

func _ready() -> void:
	_init_lanes()
	if hand_view:
		hand_view.visible = is_human

func _init_lanes() -> void:
	lane_views.clear()
	var lane_scene: PackedScene = load("res://scenes/match/Lane.tscn")
	# Ensure 3 lanes
	for child in lanes_container.get_children():
		child.queue_free()
	for i in range(3):
		var lane: LaneView = lane_scene.instantiate()
		lane.lane_index = i
		lane.kingdom_view = self
		lane.card_dropped_in_lane.connect(_on_card_dropped_in_lane)
		lanes_container.add_child(lane)
		lane_views.append(lane)

func bind_state(state: KingdomState, p_is_human: bool = false) -> void:
	kingdom_state = state
	is_human = p_is_human
	if not is_inside_tree():
		return
	update_view()

func update_view() -> void:
	if not kingdom_state:
		return

	if life_label:
		life_label.text = "Life: %d" % kingdom_state.life

	if hand_view:
		hand_view.visible = is_human
		if is_human:
			hand_view.set_hand(kingdom_state.hand)
			for child in hand_view.get_children():
				if child is CardView:
					_connect_card_view_floop(child)

	# Ensure lane views match state.lanes (3 lanes, each containing 0 or 1 creature)
	for i in range(mini(lane_views.size(), kingdom_state.lanes.size())):
		var lane_occupants: Array = kingdom_state.lanes[i]
		if not lane_occupants.is_empty():
			lane_views[i].set_occupant(lane_occupants[0])
			if lane_views[i].current_card_view:
				_connect_card_view_floop(lane_views[i].current_card_view)
		else:
			lane_views[i].set_occupant(null)

func _connect_card_view_floop(card_view: CardView) -> void:
	if not card_view:
		return
	if not card_view.floop_triggered.is_connected(_on_card_floop_triggered):
		card_view.floop_triggered.connect(_on_card_floop_triggered)

func _on_card_floop_triggered(card_view: CardView) -> void:
	if decision_source != null and card_view and card_view.card_data:
		decision_source.queue_floop(card_view.card_data)

func _on_card_dropped_in_lane(card_view: CardView, lane_index: int) -> void:
	if kingdom_state and card_view and card_view.card_data:
		var card: CardResource = card_view.card_data
		if decision_source != null:
			decision_source.queue_card_play(card, lane_index)
		# ponytail: direct state mutation for M1-03 checkup; route through HumanDecisionSource and RoundActions in M1-06
		kingdom_state.essence = maxi(0, kingdom_state.essence - card.essence_cost)
		kingdom_state.hand.erase(card)
		if kingdom_state.lanes[lane_index].is_empty():
			kingdom_state.lanes[lane_index].append(card)
		else:
			kingdom_state.lanes[lane_index][0] = card
		_connect_card_view_floop(card_view)
		card_play_requested.emit(card, lane_index)
