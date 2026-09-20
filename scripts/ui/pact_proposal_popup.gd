class_name PactProposalPopup
extends PanelContainer

signal proposal_sent(target_player_id: int)
signal pact_accepted(target_player_id: int)
signal essence_lend_requested(target_player_id: int)
signal closed()

@onready var player_list: VBoxContainer = $VBoxContainer/ScrollContainer/PlayerList
@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var local_player_id: int = 0
var context: MatchContext = null
var row_map: Dictionary = {}

func _ready() -> void:
	if not close_button:
		close_button = get_node_or_null("VBoxContainer/Header/CloseButton")
	if not player_list:
		player_list = get_node_or_null("VBoxContainer/ScrollContainer/PlayerList")
	if not status_label:
		status_label = get_node_or_null("VBoxContainer/StatusLabel")

	if close_button != null and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)

	if PactManager != null:
		if not PactManager.pact_formed.is_connected(_on_pact_changed):
			PactManager.pact_formed.connect(_on_pact_changed)
		if not PactManager.pact_broken.is_connected(_on_pact_changed):
			PactManager.pact_broken.connect(_on_pact_changed)
		if not PactManager.pact_proposed.is_connected(_on_pact_changed):
			PactManager.pact_proposed.connect(_on_pact_changed)
		if not PactManager.essence_lent.is_connected(_on_essence_lent):
			PactManager.essence_lent.connect(_on_essence_lent)

func setup(p_local_player_id: int, p_context: MatchContext) -> void:
	local_player_id = p_local_player_id
	context = p_context
	refresh()

func refresh() -> void:
	if not player_list:
		player_list = get_node_or_null("VBoxContainer/ScrollContainer/PlayerList")
	if player_list == null:
		return

	for c in player_list.get_children():
		c.queue_free()
	row_map.clear()

	if context == null:
		return

	for k in context.kingdoms:
		if k.player_id == local_player_id:
			continue
		if k.is_eliminated:
			continue
		_create_player_row(k)

func _create_player_row(opponent: KingdomState) -> void:
	var row := HBoxContainer.new()
	row.name = "PlayerRow_%d" % opponent.player_id

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Player %d (Life: %d)" % [opponent.player_id, opponent.life]
	name_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_label)

	var has_pact := PactManager.has_pact(local_player_id, opponent.player_id) if PactManager != null else false
	var incoming := PactManager.is_pact_proposed(opponent.player_id, local_player_id) if PactManager != null else false
	var outgoing := PactManager.is_pact_proposed(local_player_id, opponent.player_id) if PactManager != null else false

	var status_text := "Neutral"
	if has_pact:
		status_text = "Allied"
	elif incoming:
		status_text = "Proposal Received"
	elif outgoing:
		status_text = "Proposal Pending"

	var state_label := Label.new()
	state_label.name = "StateLabel"
	state_label.text = status_text
	state_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(state_label)

	# Propose button
	var propose_btn := Button.new()
	propose_btn.name = "ProposeButton"
	propose_btn.text = "Propose"
	propose_btn.disabled = has_pact or outgoing
	propose_btn.visible = not has_pact and not incoming
	propose_btn.pressed.connect(func(): _on_propose_clicked(opponent.player_id))
	row.add_child(propose_btn)

	# Accept button
	var accept_btn := Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "Accept"
	accept_btn.visible = incoming and not has_pact
	accept_btn.pressed.connect(func(): _on_accept_clicked(opponent.player_id))
	row.add_child(accept_btn)

	# Lend essence button
	var lend_btn := Button.new()
	lend_btn.name = "LendButton"
	lend_btn.text = "Lend 1 Essence"
	lend_btn.visible = has_pact
	var can_lend := PactManager.can_lend_essence(local_player_id, opponent.player_id, context, 1) if PactManager != null else false
	lend_btn.disabled = not can_lend
	lend_btn.pressed.connect(func(): _on_lend_clicked(opponent.player_id))
	row.add_child(lend_btn)

	player_list.add_child(row)
	row_map[opponent.player_id] = row

func _on_propose_clicked(target_id: int) -> void:
	if PactManager != null:
		PactManager.propose_pact(local_player_id, target_id)
	proposal_sent.emit(target_id)
	if status_label != null:
		status_label.text = "Sent proposal to Player %d" % target_id
	refresh()

func _on_accept_clicked(target_id: int) -> void:
	if PactManager != null:
		PactManager.accept_pact(local_player_id, target_id)
	pact_accepted.emit(target_id)
	if status_label != null:
		status_label.text = "Formed Pact with Player %d" % target_id
	refresh()

func _on_lend_clicked(target_id: int) -> void:
	if PactManager != null:
		var ok := PactManager.lend_essence(local_player_id, target_id, context, 1)
		if ok:
			essence_lend_requested.emit(target_id)
			if status_label != null:
				status_label.text = "Lent 1 Essence to Player %d" % target_id
	refresh()

func _on_pact_changed(_a: int, _b: int) -> void:
	refresh()

func _on_essence_lent(_from: int, _to: int, _amt: int) -> void:
	refresh()

func close() -> void:
	visible = false
	closed.emit()
