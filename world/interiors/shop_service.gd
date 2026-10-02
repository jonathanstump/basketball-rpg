class_name ShopService
extends RefCounted
## Shopkeepers (spec §3.4): The Plug (kicks & gear), Gripz at Pump & Grip
## (balls, upgrades), Ink at Ink & Needle (tattoos), plus the bodega counter.
## TODO(spec §10): stock, buying, selling, upgrades and tattoos land in M7.


static func keeper(kind: String) -> String:
	return {"plug": "The Plug", "pump_grip": "Gripz", "ink_needle": "Ink"}.get(kind, "the owner")


static func on_enter(it: Interior) -> void:
	var line: String = {"plug": "I got a guy everywhere. What size you wear?", "pump_grip": "Grip it right and the ball does half the work.", "ink_needle": "Pick a flash. It's on you for good."}.get(it.kind, "")
	EventBus.dialogue_requested.emit(keeper(it.kind), PackedStringArray([line]))


static func open(it: Interior) -> void:
	var opts: Array[Dictionary] = [{"id": "_leave", "label": "Just looking", "detail": "Stock arrives soon."}]
	it._open_menu(ListMenu.new(), keeper(it.kind).to_upper(), opts, func(_id: String) -> void: it.close_menu())


static func open_bodega(it: Interior) -> void:
	open(it)
