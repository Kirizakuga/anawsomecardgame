class_name KingdomStateCheck
extends RefCounted

static func run() -> void:
	var kingdom := KingdomState.new()
	assert(kingdom.life == 25)
	assert(kingdom.essence == 0)
	assert(kingdom.lanes.size() == 3)
	assert(kingdom.hand.is_empty())
	
	var card := CardResource.new()
	kingdom.hand.append(card)
	assert(kingdom.hand.size() == 1)
	assert(kingdom.hand.pop_back() == card)
	assert(kingdom.hand.is_empty())
	
	kingdom.life -= 7
	assert(kingdom.life == 18)
