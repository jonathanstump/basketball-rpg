class_name SimPresenter
extends Node
## Turns simulation events into presentation (spec §7.14, §12.1): ball and
## hoop views, sticker popups, net swishes, screen shake, EventBus forwarding.
## Owned by GameWorld; never mutates the sim.

var game: GameWorld
var ball_views: Dictionary = {}    # ball id -> BallView
var hoop_views: Dictionary = {}    # hoop id -> HoopView
var kicks_views: Dictionary = {}   # wire kicks id -> WireKicksView

const GRADE_TEXT: Dictionary = {
	"PERFECT": ["SPLASH!", "splash"], "GOOD": ["BUCKET!", "good"],
	"NEAR_MISS": ["RIM OUT", "miss"], "BRICK": ["BRICK", "miss"], "REJECTED": ["REJECTED!", "bad"],
}


func _init(g: GameWorld) -> void:
	game = g
	name = "SimPresenter"


func add_hoop_view(h: SimHoop) -> HoopView:
	var v: HoopView = HoopView.create(h)
	game.add_child(v)
	hoop_views[h.id] = v
	return v


func add_wire_kicks_view(id: String, pos: Vector3, wire_dir: Vector3, color: Color) -> void:
	var v: WireKicksView = WireKicksView.create(id, pos, wire_dir, color)
	game.add_child(v)
	kicks_views[id] = v


func sync_balls() -> void:
	var seen: Dictionary = {}
	for b: SimBall in game.balls.balls:
		seen[b.id] = true
		if not ball_views.has(b.id):
			var bv: BallView = BallView.create(b, game)
			game.add_child(bv)
			ball_views[b.id] = bv
		(ball_views[b.id] as BallView).physics_synced()
	for id: Variant in ball_views.keys():
		if not seen.has(id):
			(ball_views[id] as Node).queue_free()
			ball_views.erase(id)


func on_event(ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	var actor: SimActor = game.sim.actor_by_id(int(ev.get("actor", 0)))
	var at: Vector3 = actor.pos if actor != null else Vector3.ZERO
	var is_player: bool = actor != null and actor == game.player
	match t:
		"shot_released":
			EventBus.shot_released.emit(int(ev["actor"]), str(ev["grade"]))
		"shot_made":
			var g: String = str(ev["grade"])
			if is_player:
				_popup(GRADE_TEXT[g][0], at, GRADE_TEXT[g][1])
				if str(ev.get("zone", "")) in ["three", "deep"]:
					GameState.bump_counter("threes")
			var hv: HoopView = hoop_views.get(str(ev["hoop"]), null)
			if hv != null:
				hv.on_make()
			AudioDirector.play_sfx("chain_ching" if str(ev.get("net", "chain")) == "chain" else "swish", at)
		"shot_missed":
			if is_player:
				var g2: String = str(ev["grade"])
				_popup(GRADE_TEXT.get(g2, ["MISS", "miss"])[0], at, "miss")
			AudioDirector.play_sfx("rim_clank", at)
		"shot_rejected":
			_popup("REJECTED!", at, "bad")
			EventBus.screen_shake_requested.emit(0.5)
		"bucket_blast":
			_popup("BUCKET BLAST!", ev["pos"], "style")
			EventBus.screen_shake_requested.emit(0.8)
			EventBus.bucket_blast_fired.emit(str(ev["hoop"]), ev["pos"])
		"crate_first_make":
			_popup("+%d" % int(ev["tokens"]), at, "tokens")
		"wire_kicks_down":
			var wk: WireKicksView = kicks_views.get(str(ev["id"]), null)
			if wk != null:
				wk.knock_down(game.sim.collision.ground_height(ev["pos"]))
			_popup("KICKS!", ev["pos"], "tokens")
		"pass_hit":
			EventBus.screen_shake_requested.emit(0.2)
		"lob_landed":
			EventBus.screen_shake_requested.emit(0.3)
		"ball_lost":
			if int(ev.get("home", 0)) == (game.player.id if game.player != null else -1):
				EventBus.ball_lost.emit(str(ev["reason"]))
		"spare_ball":
			if is_player:
				_popup("SPARE BALL", at, "miss")
		"popup":
			_popup(str(ev.get("text", "")), ev.get("pos", at), str(ev.get("style", "good")))
		"hit_resolved":
			_on_hit(ev)
		"telegraph_circle":
			_ring(ev["pos"], float(ev["radius"]), float(ev["delay_s"]), Color("#FF3E3E"))
		"zone_spawned":
			_ring(ev["pos"], float(ev["radius"]), float(ev["duration_s"]), Color("#F2F2F2") if str(ev.get("zone", "")) == "white" else Color("#FF7A20"))
		"move_started":
			if bool(ev.get("unblockable", false)):
				var ua: SimActor = game.sim.actor_by_id(int(ev["actor"]))
				if ua != null:
					_popup("!", ua.pos + Vector3(0, ua.height * 0.4, 0), "bad")
		"composure_broken":
			var who: SimActor = game.sim.actor_by_id(int(ev["actor"]))
			if who != null and who != game.player:
				_popup("SHOOK!" if str(ev["kind"]) == "shook" else "STAGGER!", who.pos, "style")
				EventBus.composure_broken.emit(who.id, str(ev["kind"]))
		"actor_killed":
			var dead: SimActor = game.sim.actor_by_id(int(ev["actor"]))
			EventBus.actor_died.emit(int(ev["actor"]), str(ev["kind"]))
			if dead != null and dead != game.player and game.views.has(dead.id):
				var v: Node3D = game.views[dead.id]
				var tw: Tween = v.create_tween()
				tw.tween_interval(1.2)
				tw.tween_property(v, "scale", Vector3(1.2, 0.01, 1.2), 0.35)
		"takeover_started":
			if is_player:
				_popup("ON FIRE!", at, "big")
				EventBus.takeover_started.emit()
		"takeover_ended":
			if is_player:
				EventBus.takeover_ended.emit()
		"taunt_completed":
			_popup("+HYPE", at, "hype")
			EventBus.taunt_completed.emit(int(ev["actor"]))
			if is_player:
				GameState.bump_counter("taunts")
		"hype_short":
			if is_player:
				_popup("NEED HYPE", at, "miss")
		"qw_empty":
			if is_player:
				_popup("NO WATER", at, "miss")
		"healed":
			if is_player:
				_popup("+%d" % int(ev["amount"]), at, "good")
		"steal":
			_popup("PICKED!", at, "style")
		"rose_saved":
			_popup("NOT TODAY", at, "hype")


func _on_hit(ev: Dictionary) -> void:
	var r: String = str(ev["result"])
	var tgt: SimActor = game.sim.actor_by_id(int(ev["target"]))
	var att: SimActor = game.sim.actor_by_id(int(ev["attacker"]))
	var tpos: Vector3 = tgt.pos if tgt != null else Vector3.ZERO
	match r:
		"ankle_breaker":
			_popup("ANKLES!", tpos, "big")
			EventBus.slowmo_requested.emit(0.3, 0.6)
			EventBus.ankle_broken.emit(int(ev["target"]), int(ev["attacker"]))
			AudioDirector.play_sfx("crowd_ooh", tpos)
			if tgt == game.player:
				GameState.bump_counter("ankle_breakers")
		"strip":
			_popup("STRIP!", tpos, "style")
			EventBus.strip_landed.emit(int(ev["target"]), int(ev["attacker"]))
			if tgt == game.player:
				GameState.bump_counter("strips")
		"deflect":
			_popup("DEFLECT", tpos, "good")
			EventBus.deflect_landed.emit(int(ev["target"]), int(ev["attacker"]))
		"read":
			_popup("READ", tpos, "good")
		"rejection":
			_popup("GET THAT OUTTA HERE!", tpos, "style")
			EventBus.rejection_landed.emit(int(ev["target"]), int(ev["attacker"]))
		"guarded":
			_popup("BLOCK", tpos, "miss")
		"guard_break":
			_popup("GUARD BREAK", tpos, "bad")
			EventBus.screen_shake_requested.emit(0.6)
		"hit":
			var dmg: float = float(ev.get("damage", 0.0))
			EventBus.actor_damaged.emit(int(ev["target"]), dmg, int(ev["attacker"]))
			if tgt != null and game.views.has(tgt.id):
				(game.views[tgt.id] as ActorView).flash()
			var heavy: bool = str(ev.get("weight", "")) == "heavy"
			EventBus.screen_shake_requested.emit(0.45 if heavy else 0.18)
			if tgt == game.player:
				EventBus.screen_shake_requested.emit(0.5)
			elif att == game.player and dmg > 0.0:
				_popup(("%d!" if bool(ev.get("crit", false)) else "%d") % int(dmg), tpos, "damage")


func _popup(text: String, pos: Variant, style: String) -> void:
	var p: Vector3 = pos if pos is Vector3 else Vector3.ZERO
	EventBus.popup_text.emit(text, p, style)


func _ring(pos: Vector3, radius: float, life_s: float, col: Color) -> void:
	## Ground telegraph (spec §8.1 "ground reticle"): a flat ring that fills in.
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.torus(maxf(0.05, radius - 0.12), radius)
	mi.material_override = ToonMaterials.neon(col, 2.5)
	mi.position = Vector3(pos.x, game.sim.collision.ground_height(pos + Vector3(0, 2, 0)) + 0.05, pos.z)
	mi.scale = Vector3(1, 0.15, 1)
	game.add_child(mi)
	var fill: MeshInstance3D = MeshInstance3D.new()
	fill.mesh = MeshLib.cylinder(radius, 0.02)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(col.r, col.g, col.b, 0.25)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.material_override = fm
	fill.scale = Vector3(0.05, 1, 0.05)
	mi.add_child(fill)
	var tw: Tween = mi.create_tween()
	tw.tween_property(fill, "scale", Vector3(1, 1, 1), maxf(0.05, life_s))
	tw.tween_callback(mi.queue_free)
