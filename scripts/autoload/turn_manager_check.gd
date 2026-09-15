extends Node

var observed_phases: Array[int] = []
var started_turns: Array[int] = []
var ended_turns: Array[int] = []

func _ready() -> void:
	TurnManager.phase_changed.connect(_on_phase_changed)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)

	for _turn in range(3):
		TurnManager.start_turn()
		TurnManager.next_phase()
		TurnManager.next_phase()
		TurnManager.next_phase()
		TurnManager.next_phase()

	var expected_phases: Array[int] = []
	for _turn in range(3):
		expected_phases.append_array([
			TurnManager.Phase.ESSENCE,
			TurnManager.Phase.PLAY,
			TurnManager.Phase.BATTLE,
			TurnManager.Phase.CLEANUP,
		])

	assert(observed_phases == expected_phases)
	assert(started_turns == [1, 2, 3])
	assert(ended_turns == [1, 2, 3])
	print("TurnManagerCheck: PASS")
	get_tree().quit()

func _on_phase_changed(phase: TurnManager.Phase) -> void:
	observed_phases.append(phase)

func _on_turn_started(turn_number: int) -> void:
	started_turns.append(turn_number)

func _on_turn_ended(turn_number: int) -> void:
	ended_turns.append(turn_number)