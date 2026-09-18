extends Node

func _ready() -> void:
	var kingdom_scene: PackedScene = load("res://scenes/match/Kingdom.tscn")
	assert(kingdom_scene != null, "Kingdom scene must exist")

	var kingdom_view: KingdomView = kingdom_scene.instantiate()
	add_child(kingdom_view)

	# Set up KingdomState per M1-03 checkup: 2 creatures in lanes, Life = 15
	var state := KingdomState.new(0)
	state.life = 15

	var goblin: CreatureResource = CardDatabase.get_card("cr_goblin_scout") as CreatureResource
	var drake: CreatureResource = CardDatabase.get_card("cr_flame_drake") as CreatureResource
	var fireball: SpellResource = CardDatabase.get_card("sp_fireball") as SpellResource
	assert(goblin != null and drake != null and fireball != null, "Cards must load from database")

	state.lanes[0].append(goblin)
	state.lanes[1].append(drake)
	# Lane 2 remains empty

	state.hand.append(goblin)

	# Bind state to KingdomView (human player)
	kingdom_view.bind_state(state, true)

	# 1. Verify Life display
	assert(kingdom_view.life_label.text == "Life: 15", "Life label should display 15, got %s" % kingdom_view.life_label.text)

	# 2. Verify Lanes reflection
	assert(kingdom_view.lane_views.size() == 3, "Must have 3 lane views")
	assert(kingdom_view.lane_views[0].is_occupied() == true, "Lane 0 must be occupied")
	assert(kingdom_view.lane_views[0].current_card_view.card_data == goblin, "Lane 0 card must be goblin")
	assert(kingdom_view.lane_views[1].is_occupied() == true, "Lane 1 must be occupied")
	assert(kingdom_view.lane_views[1].current_card_view.card_data == drake, "Lane 1 card must be drake")
	assert(kingdom_view.lane_views[2].is_occupied() == false, "Lane 2 must be unoccupied")

	# 3. Verify Hand visibility for human vs non-human
	assert(kingdom_view.hand_view.visible == true, "Human hand should be visible")
	assert(kingdom_view.hand_view.get_child_count() == 1, "Hand should have 1 card view")
	kingdom_view.bind_state(state, false)
	assert(kingdom_view.hand_view.visible == false, "Bot hand should be hidden")
	kingdom_view.bind_state(state, true)

	# 4. Verify Lane drop validity checks
	var empty_lane: LaneView = kingdom_view.lane_views[2]
	var occupied_lane: LaneView = kingdom_view.lane_views[0]

	# Insufficient essence rejects drop (M1-02 criteria)
	state.essence = 0
	assert(empty_lane._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": goblin}) == false, "Insufficient essence must reject drop")

	# Grant essence
	state.essence = 3

	# Occupied lane rejects drop
	assert(occupied_lane._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": goblin}) == false)
	# Empty lane accepts creature drop
	assert(empty_lane._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": goblin}) == true)
	# Empty lane rejects spell drop
	assert(empty_lane._can_drop_data(Vector2.ZERO, {"type": "card", "card_data": fireball}) == false)

	# 5. Verify actual drop from hand into lane
	var hand_card_view: CardView = kingdom_view.hand_view.get_child(0) as CardView
	assert(hand_card_view != null, "Hand must contain a CardView")
	empty_lane._drop_data(Vector2.ZERO, {"type": "card", "card_data": goblin, "source_view": hand_card_view})

	# Hand card moved to lane
	assert(empty_lane.is_occupied() == true, "Lane 2 should now be occupied")
	assert(empty_lane.current_card_view == hand_card_view, "Lane 2 should hold the dropped CardView")
	assert(kingdom_view.hand_view.get_child_count() == 0, "Hand should now be empty")
	assert(state.hand.is_empty(), "KingdomState.hand should be empty")
	assert(state.lanes[2].size() == 1 and state.lanes[2][0] == goblin, "KingdomState.lanes[2] should have goblin")
	assert(state.essence == 2, "Essence should be deducted after playing card")

	print("KingdomCheck: PASS")
	get_tree().quit()
