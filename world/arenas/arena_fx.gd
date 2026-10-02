class_name ArenaFx
extends RefCounted
## Presentation for boss gimmick sim events (spec §9.3): Barker mirror clones
## (no shadow), shatters, floor tilt; Toll booth payouts/spills, the Toll
## Gate wall, Rush Hour headlight beams, Bridge Collapse safe lane.


static func on_event(arena: BossArena, ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	match t:
		"boss_clone_spawned":
			var c: SimActor = arena.sim.actor_by_id(int(ev["actor"]))
			if c != null:
				var v: BossView = BossView.create_boss(c, arena.boss_data)
				var blob: Node = v.get_node_or_null("Blob")
				if blob != null:
					blob.queue_free()
				_no_shadows(v)
				arena.add_child(v)
				arena.views[c.id] = v
		"clone_shattered":
			var id: int = int(ev["actor"])
			if arena.views.has(id):
				(arena.views[id] as Node).queue_free()
				arena.views.erase(id)
			if not bool(ev.get("quiet", false)):
				EventBus.popup_text.emit("SHATTER!", ev["pos"], "style")
				EventBus.flash_requested.emit("hit")
		"shell_game":
			EventBus.popup_text.emit("FOLLOW THE SHADOW", arena.player.pos, "miss")
		"floor_tilt":
			if (ev["dir"] as Vector3) != Vector3.ZERO:
				arena.boss_bar.show_banner("TILT!", 1.0)
				EventBus.screen_shake_requested.emit(0.4)
		"toll_paid":
			EventBus.popup_text.emit("PAY UP! -%d" % int(ev["amount"]), arena.player.pos, "bad")
			EventBus.popup_text.emit("STRIP HIM!", ev["pos"], "style")
		"toll_spilled":
			if int(ev["amount"]) > 0:
				EventBus.popup_text.emit("+%d TOKENS" % int(ev["amount"]), ev["pos"], "tokens")
		"toll_gate_up":
			_toll_gate(arena, ev)
		"toll_gate_down":
			var g: Node = arena.get_node_or_null("TollGateFx")
			if g != null:
				g.queue_free()
		"headlight_on":
			_headlight(arena, ev)
		"orbits_on", "globe_dropped":
			if arena.get_node_or_null("OrbitFx") == null and arena.boss != null and (arena.boss.controller as BossBrain).gimmick is AtlasGimmick:
				var fx: OrbitFx = OrbitFx.new()
				fx.name = "OrbitFx"
				fx.gimmick = (arena.boss.controller as BossBrain).gimmick as AtlasGimmick
				arena.add_child(fx)
		"car_decoupled":
			var car: SimActor = arena.sim.actor_by_id(int(ev["actor"]))
			if car != null:
				var cv: BossView = BossView.create_boss(car, arena.boss_data)
				cv.scale = Vector3.ONE * 0.8
				arena.add_child(cv)
				arena.views[car.id] = cv
		"car_removed":
			if arena.views.has(int(ev["actor"])):
				(arena.views[int(ev["actor"])] as Node).queue_free()
		"commuter":
			var cm: MeshInstance3D = MeshInstance3D.new()
			cm.mesh = MeshLib.capsule(0.35, 1.8)
			cm.material_override = ToonMaterials.toon(Color("#1A1A24"))
			cm.position = (ev["pos"] as Vector3) + Vector3(0, 0.9, 0)
			cm.add_to_group("commuters")
			arena.add_child(cm)
		"crowd_cleared":
			for n: Node in arena.get_tree().get_nodes_in_group("commuters"):
				n.queue_free()
		"eclipse":
			pass
		"safe_lane":
			arena.boss_bar.show_banner("FIND THE LANE!", 1.2)
			_lane_marker(arena, float(ev["x"]), float(ev["width"]))


static func _no_shadows(n: Node) -> void:
	for ch: Node in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadows(ch)


static func _toll_gate(arena: BossArena, ev: Dictionary) -> void:
	var old: Node = arena.get_node_or_null("TollGateFx")
	if old != null:
		old.free()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "TollGateFx"
	mi.mesh = MeshLib.box(Vector3(float(ev["width"]), 2.6, 0.5))
	mi.material_override = ToonMaterials.toon(Color("#F4B400"), true, false, Color("#F4B400"), 0.5)
	mi.position = (ev["pos"] as Vector3) + Vector3(0, 1.3, 0)
	arena.add_child(mi)
	EventBus.popup_text.emit("TOLL GATE!", ev["pos"], "bad")


static func _headlight(arena: BossArena, ev: Dictionary) -> void:
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.mesh = MeshLib.box(Vector3(3.2, 0.05, 40.0))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.6, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var x0: float = float(ev["x"])
	beam.position = Vector3(x0, 0.06, 0)
	arena.add_child(beam)
	var light: SpotLight3D = SpotLight3D.new()
	light.light_color = Color("#FFF2B0")
	light.light_energy = 6.0
	light.spot_range = 30.0
	light.spot_angle = 12.0
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.position = Vector3(0, 14.0, 0)
	beam.add_child(light)
	var tw: Tween = arena.create_tween()
	tw.tween_property(beam, "position:x", x0 + float(ev["dir"]) * float(ev["half_w"]) * 2.0, float(ev["sweep_s"]))
	tw.tween_callback(beam.queue_free)


static func _lane_marker(arena: BossArena, x: float, width: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.box(Vector3(width * 0.8, 0.03, 30.0))
	mi.material_override = ToonMaterials.neon(Color("#00E58A"), 1.5)
	mi.position = Vector3(x, 0.03, 0)
	arena.add_child(mi)
	arena.get_tree().create_timer(3.0).timeout.connect(mi.queue_free)
