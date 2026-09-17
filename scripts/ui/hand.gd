class_name HandView
extends HBoxContainer

signal card_drag_started(card_view: CardView)

func _ready() -> void:
	custom_minimum_size = Vector2(300, 150)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)

func set_hand(cards: Array[CardResource]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var cv_scene: PackedScene = load("res://scenes/match/CardView.tscn")
	for card in cards:
		var cv: CardView = cv_scene.instantiate()
		cv.card_data = card
		add_child(cv)

func remove_card(card_view: CardView) -> void:
	if card_view and card_view.get_parent() == self:
		remove_child(card_view)
