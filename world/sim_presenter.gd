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


func _popup(text: String, pos: Variant, style: String) -> void:
	var p: Vector3 = pos if pos is Vector3 else Vector3.ZERO
	EventBus.popup_text.emit(text, p, style)
