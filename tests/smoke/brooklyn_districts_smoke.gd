extends Node
## Smoke (spec §16 M8): Coney Island and DUMBO build, spawn their crews, and
## their tags, NPCs, shoeboxes, shortcuts and secrets all respond.

var problems: PackedStringArray = PackedStringArray()


func _ready() -> void:
	GameState.new_run("two_way", "brooklyn", {"name": "Smoke"})
	GameState.add_item("box_key", 10)
	for id: String in ["bk_coney", "bk_dumbo"]:
		SceneRouter.pending = {"district": id}
		var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
		add_child(d)
		await _frames(90)
		if d.player == null or not d.player.alive:
			problems.append("%s: no live player" % id)
		if d.spawner.alive_count() < 5:
			problems.append("%s: only %d enemies alive" % [id, d.spawner.alive_count()])
		var kinds: Dictionary = {}
		for it: Dictionary in d.interact.items.duplicate():
			kinds[str(it["kind"])] = int(kinds.get(str(it["kind"]), 0)) + 1
			if str(it["kind"]) in ["tag", "box", "secret"]:
				d.player.pos = it["pos"]
				DistrictActions.trigger(d, it)
			elif str(it["kind"]) == "npc" and JU.dict(it["data"] as Dictionary, "challenger").is_empty():
				DistrictActions.trigger(d, it)
			d.close_menu()
		for k: String in ["bodega", "station", "court", "crossing", "box", "tag", "npc", "shortcut", "secret"]:
			if not kinds.has(k):
				problems.append("%s: no %s interactable" % [id, k])
		await _frames(10)
		d.queue_free()
		await _frames(2)
	if problems.is_empty():
		print("SMOKE OK brooklyn_districts_smoke")
	else:
		for p: String in problems:
			push_error("brooklyn_districts_smoke: " + p)
	get_tree().quit()


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
