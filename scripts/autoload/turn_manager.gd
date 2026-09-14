extends Node

signal phase_changed(phase: Phase)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)

enum Phase { ESSENCE, PLAY, BATTLE, CLEANUP }

var current_phase: Phase = Phase.ESSENCE
var current_turn: int = 0

func start_turn() -> void:
	current_turn += 1
	turn_started.emit(current_turn)
	advance_phase(Phase.ESSENCE)

func advance_phase(phase: Phase) -> void:
	current_phase = phase
	phase_changed.emit(current_phase)

func next_phase() -> void:
	match current_phase:
		Phase.ESSENCE:
			advance_phase(Phase.PLAY)
		Phase.PLAY:
			advance_phase(Phase.BATTLE)
		Phase.BATTLE:
			advance_phase(Phase.CLEANUP)
		Phase.CLEANUP:
			turn_ended.emit(current_turn)
