extends Node
## Persistent driver for district_walk_smoke (see that file).

var seen: Dictionary = {}
var walker: QAWalker = QAWalker.new()
var step: int = 0
var t: int = 0
var loads: int = 0


func _ready() -> void:
	GameState.new_run("two_way", "brooklyn")
	DebugConsole.god_mode = true
	EventBus.box_opened.connect(func(_id: String, _items: PackedStringArray) -> void: seen["box"] = true)
	EventBus.station_discovered.connect(func(_id: String) -> void: seen["station"] = true)
	EventBus.rested.connect(func(_id: String) -> void: seen["rest"] = true)
	EventBus.district_loaded.connect(func(_id: String) -> void: loads += 1)
	SceneRouter.goto_district("bk_bedstuy", {}, false)


func _physics_process(_delta: float) -> void:
	t += 1
	var scene: Node = get_tree().current_scene
	if t > 5000:
		_finish("timeout at step %d" % step)
		return
	match step:
		0:
			if scene is District and (scene as District).player != null:
				var d: District = scene
				d.use_scripted_input(walker)
				var box: Dictionary = {}
				for b: Variant in JU.a(d.layout, "boxes"):
					if not bool((b as Dictionary)["locked"]) and box.is_empty():
						box = b
				_near(d, box["pos"])
				walker.go(box["pos"], true, 1.2)
				step = 1
		1:
			if seen.has("box"):
				var d2: District = scene
				var st: Dictionary = (d2.layout["stations"] as Array)[0]
				_near(d2, st["pos"])
				walker.go(st["pos"], true, 1.6)
				step = 2
		2:
			if scene is District and (scene as District).menu is ListMenu:
				((scene as District).menu as ListMenu).chosen.emit("_leave")
				var d3: District = scene
				var bd: Dictionary = (d3.layout["bodegas"] as Array)[0]
				_near(d3, bd["door"])
				walker.go(bd["door"], true, 2.0)
				step = 3
		3:
			if scene is Interior and (scene as Interior).player != null:
				var it: Interior = scene
				walker = QAWalker.new()
				it.use_scripted_input(walker)
				walker.go(Vector3(-2.6, 0, -1.6), true, 1.2)
				step = 4
		4:
			if seen.has("rest") and scene is Interior:
				var it2: Interior = scene
				it2.trigger("counter")
				(it2.menu as ListMenu).chosen.emit("travel")
				(it2.menu as ListMenu).chosen.emit("bk_st_bedstuy")
				step = 5
		5:
			if loads >= 2 and scene is District and (scene as District).player != null:
				_finish("")


func _near(d: GameWorld, p: Vector3) -> void:
	## Short hop: put the bot ~6 m from the target so it walks the last leg.
	var to: Vector3 = d.player.pos - p
	to.y = 0.0
	if to.length() > 7.0:
		d.player.pos = d.sim.collision.resolve(p + to.normalized() * 6.0 + Vector3(0, 0.2, 0), d.player.radius)


func _finish(problem: String) -> void:
	set_physics_process(false)
	var problems: PackedStringArray = PackedStringArray()
	if problem != "":
		problems.append(problem)
	for k: String in ["box", "station", "rest"]:
		if not seen.has(k):
			problems.append("missing " + k)
	DebugConsole.god_mode = false
	if problems.is_empty():
		print("SMOKE OK district_walk_smoke (%d loads, %d frames)" % [loads, t])
	else:
		for p: String in problems:
			push_error("district_walk_smoke: " + p)
	get_tree().quit()
