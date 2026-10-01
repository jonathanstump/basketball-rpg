extends SceneTree
## Writes the data/input_map.json bindings into project.godot's [input]
## section so the editor shows the same map the game builds at runtime.


func _initialize() -> void:
	var data: Variant = JU.load_json("res://data/input_map.json")
	var d: Dictionary = data
	var dz: float = JU.f(d, "deadzone", 0.2)
	var actions: Dictionary = JU.dict(d, "actions")
	for k: Variant in actions.keys():
		var evs: Array[InputEvent] = InputSpec.events_from_spec(actions[k])
		ProjectSettings.set_setting("input/" + str(k), {"deadzone": dz, "events": evs})
	var err: Error = ProjectSettings.save()
	print("input map written: %d actions (err %d)" % [actions.size(), err])
	quit(0)
