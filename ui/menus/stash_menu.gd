class_name StashMenu
extends RefCounted
## Bodega stash (spec §5.2). TODO(spec §10.1): gear management lands in M7.


static func open(it: Interior) -> void:
	var opts: Array[Dictionary] = [{"id": "_back", "label": "Back", "detail": "%d different items carried." % GameState.inventory.size()}]
	it._open_menu(ListMenu.new(), "STASH", opts, func(_id: String) -> void: it.counter_menu())
