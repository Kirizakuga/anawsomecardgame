class_name RoundActions
extends RefCounted

var player_id: int = -1
var cards_to_play: Array[Dictionary] = []
var cards_to_floop: Array[CardResource] = []
var landscapes_to_play: Array[LandscapeResource] = []
var attack_targets: Array[Dictionary] = []
var pact_proposals: Array[Dictionary] = []
var betrayal_target: int = -1
