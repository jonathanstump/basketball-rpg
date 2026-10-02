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
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	for e: Variant in entries:
		var entry: Dictionary = e
		if not only.is_empty() and not only.has(JU.s(entry, "name")):
			continue
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
		if OS.get_environment("CC_SHADOW_DEBUG") == "1":
			var tally: Dictionary = {}
			for g: Node in inst.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = g
				if gi.is_visible_in_tree() and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					var k: String = "%s %s" % [gi.get_class(), str(gi.get_parent().name)]
					tally[k] = int(tally.get(k, 0)) + 1
			for k: Variant in tally.keys():
				if int(tally[k]) >= 5:
					print("CASTERS %s %d" % [k, int(tally[k])])
		var lights: int = 0
		for n: Node in inst.find_children("*", "Light3D", true, false):
			if (n as Light3D).visible:
				lights += 1
		print("RENDER STATS %s draw_calls=%d objects=%d lights=%d vram_mb=%.0f static_mb=%.0f fps_frame_ms=%.2f" % [JU.s(entry, "name"),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			lights, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		shot_count += 1
		inst.queue_free()
		await process_frame
	print("RENDER DONE %d shots" % shot_count)
	quit(0)
