extends Node

signal pact_formed(player_a: int, player_b: int)
signal pact_broken(breaker: int, victim: int)

func propose_pact(_from: int, _to: int) -> void:
	pass  # ponytail: stub — implement in Phase 4

func accept_pact(_from: int, _to: int) -> void:
	pass

func break_pact(_breaker: int, _victim: int) -> void:
	pass
