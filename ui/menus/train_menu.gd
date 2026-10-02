class_name TrainMenu
extends RefCounted
## Bodega "Train" (spec §5.7). TODO(spec §11.3): leveling with Rep lands in M7.


static func open(it: Interior) -> void:
	var opts: Array[Dictionary] = [{"id": "_back", "label": "Back", "detail": "Level %d  -  %d Rep unspent." % [GameState.level, GameState.rep]}]
	it._open_menu(ListMenu.new(), "TRAIN", opts, func(_id: String) -> void: it.counter_menu())
