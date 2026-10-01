extends SceneTree
## Render smoke (spec §15.16 step 5): loads each scene in
## tools/render_scenes.json with a real renderer, waits, and saves a PNG to
## shots/. Usage: $GODOT --path . -s res://tools/screenshot.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var list: Variant = JU.load_json("res://tools/render_scenes.json")
	var entries: Array = (list as Dictionary).get("scenes", []) if list is Dictionary else []
	var out_dir: String = ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shot_count: int = 0
	for e: Variant in entries:
		var entry: Dictionary = e
		var path: String = JU.s(entry, "scene")
		var ps: PackedScene = load(path)
		if ps == null:
			print("RENDER FAIL: cannot load " + path)
			continue
		var inst: Node = ps.instantiate()
		if inst.has_method("setup_render_smoke"):
			inst.call("setup_render_smoke", entry)
		root.add_child(inst)
		for _i: int in JU.i(entry, "frames", 60):
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var file: String = out_dir.path_join(JU.s(entry, "name", "shot") + ".png")
		img.save_png(file)
		print("RENDER SHOT %s (%dx%d)" % [file, img.get_width(), img.get_height()])
		shot_count += 1
		inst.queue_free()
		await process_frame
	print("RENDER DONE %d shots" % shot_count)
	quit(0)
