class_name ArenaBuilder
extends RefCounted
## Arena template (spec §9.1): half-court with a painted 6.75 m arc,
## regulation 3.05 m rim behind the boss, chain-link fence with a gate that
## slams shut, apron, and a theme hook for per-boss dressing. Collision is
## always built (boss sims run headless); visuals only when `parent` is set.

const APRON_M: float = 2.5


static func build(w: SimWorld, b: BallSystem, boss: Dictionary, parent: Node3D) -> Dictionary:
	var arena: Dictionary = JU.dict(boss, "arena")
	var size: Array = JU.a(arena, "size_m")
	var sx: float = float(size[0]) if size.size() > 0 else 18.0
	var sz: float = float(size[1]) if size.size() > 1 else 16.0
	var half: Vector2 = Vector2(sx, sz) * 0.5
	var indoor: bool = JU.b(arena, "indoor")
	var hoop: SimHoop = b.add_hoop(SimHoop.regulation("arena_hoop", Vector3(0, 0, -half.y + 1.2), Vector3(0, 0, 1), 3.05, "nylon" if indoor else "chain"))
	var lay: Dictionary = {
		"hoop": hoop,
		"boss_spot": hoop.floor_point() + hoop.facing * 2.2,
		"top_of_key": hoop.floor_point() + hoop.facing * 7.6,
		"player_start": Vector3(0, 0, half.y - 1.5),
		"gate": Vector3(0, 0, half.y + APRON_M),
		"gate_outside": Vector3(0, 0, half.y + APRON_M + 3.0),
		"half": half,
	}
	var bmin: Vector2 = -half - Vector2(APRON_M, APRON_M)
	var bmax: Vector2 = half + Vector2(APRON_M, APRON_M)
	w.collision.set_bounds(bmin - Vector2(1, 1), bmax + Vector2(1, 6))
	# Fence walls (the gate segment is tagged so it can open/close).
	var t: float = 0.3
	w.collision.add_block(Vector2(bmin.x - t, bmin.y - t), Vector2(bmax.x + t, bmin.y), 4.0, "fence")
	w.collision.add_block(Vector2(bmin.x - t, bmin.y), Vector2(bmin.x, bmax.y), 4.0, "fence")
	w.collision.add_block(Vector2(bmax.x, bmin.y), Vector2(bmax.x + t, bmax.y), 4.0, "fence")
	w.collision.add_block(Vector2(bmin.x - t, bmax.y), Vector2(-1.6, bmax.y + t), 4.0, "fence")
	w.collision.add_block(Vector2(1.6, bmax.y), Vector2(bmax.x + t, bmax.y + t), 4.0, "fence")
	w.collision.add_block(Vector2(-1.6, bmax.y), Vector2(1.6, bmax.y + t), 4.0, "arena_gate")
	var plat: Dictionary = JU.dict(arena, "paint_platform")
	if not plat.is_empty():
		_platform(w, hoop, plat, lay)
	if parent != null:
		ArenaThemes.dress(parent, w, boss, lay)
	return lay


static func _platform(w: SimWorld, hoop: SimHoop, plat: Dictionary, lay: Dictionary) -> void:
	## Stepped platform in the paint (the Stoop Queen's stoop: "the steps are the paint").
	var steps: int = JU.i(plat, "steps", 3)
	var step_h: float = JU.f(plat, "step_h", 0.35)
	var depth: float = JU.f(plat, "depth_m", 4.5)
	var width: float = JU.f(plat, "width_m", 5.0)
	var base: Vector3 = hoop.floor_point() - hoop.facing * 0.8
	for i: int in steps:
		var top: float = step_h * float(i + 1)
		var d: float = depth - float(i) * 0.7
		var c: Vector3 = base + hoop.facing * (d * 0.5)
		w.collision.add_box(Vector3(c.x, top * 0.5, c.z), Vector3(width - float(i) * 0.4, top, d), "stoop")
	lay["boss_spot"] = base + hoop.facing * 1.5 + Vector3(0, step_h * float(steps), 0)
	lay["platform"] = {"base": base, "depth": depth, "width": width, "steps": steps, "step_h": step_h}


static func close_gate(w: SimWorld) -> void:
	for blk: Dictionary in w.collision.blocks:
		if str(blk["tag"]) == "arena_gate":
			blk["top"] = 4.0


static func open_gate(w: SimWorld) -> void:
	w.collision.remove_tag("arena_gate")
