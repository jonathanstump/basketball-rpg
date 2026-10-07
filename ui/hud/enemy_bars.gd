class_name EnemyBars
extends CanvasLayer
## Street enemy health bars and status tags (playtest: "I couldn't tell what
## my hits did"). A bar shows over a crew member's head once you've hurt
## them, with a white chip trail that drains after each hit, and a status
## tag when they're open: DOWN / SHOOK / STAGGERED -> "[R] FINISH" when you
## hold the ball and the Dunk Finisher would land. Named enemies
## (lieutenants, side-street leaders, captains) show theirs when you're near.
## Pure presentation: reads the sim, never writes it. Bosses use BossBar.

const SHOW_AFTER_HIT_S: float = 4.0
const NAMED_RANGE_M: float = 14.0
const CHIP_DELAY_S: float = 0.35
const CHIP_RATE_PER_S: float = 0.9
const BAR_W: float = 140.0
const BAR_H: float = 15.0

var game: GameWorld
var _hit_t: Dictionary = {}      # actor id -> seconds since last damage
var _chip: Dictionary = {}       # actor id -> trailing ratio
var _canvas: Control
var _clock: float = 0.0


func _ready() -> void:
	layer = 15
	_canvas = Control.new()
	_canvas.name = "Bars"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_bars)
	add_child(_canvas)
	EventBus.actor_damaged.connect(_on_damaged)


func _on_damaged(target_id: int, amount: float, _source_id: int) -> void:
	## The chip trail starts from the pre-hit health and drains after a beat.
	var a: SimActor = game.sim.actor_by_id(target_id) if game != null and game.sim != null else null
	if a != null:
		_chip[target_id] = clampf(maxf(float(_chip.get(target_id, 0.0)), (a.hp + amount) / maxf(1.0, a.hp_max)), 0.0, 1.0)
	_hit_t[target_id] = 0.0


func _process(delta: float) -> void:
	_clock += delta
	for id: Variant in _hit_t.keys():
		var t: float = float(_hit_t[id]) + delta
		_hit_t[id] = t
		var a: SimActor = game.sim.actor_by_id(int(id)) if game != null and game.sim != null else null
		var hp_r: float = a.hp / maxf(1.0, a.hp_max) if a != null else 0.0
		if t > CHIP_DELAY_S and _chip.has(id):
			_chip[id] = maxf(hp_r, float(_chip[id]) - CHIP_RATE_PER_S * delta)
	_canvas.queue_redraw()


static func is_street_hostile(a: SimActor) -> bool:
	return a != null and a.team != 0 and (a.kind == "enemy" or a.kind == "critter") and not bool(a.flags.get("prop_target", false))


static func is_named(a: SimActor) -> bool:
	return a.flags.has("lieutenant") or bool(a.flags.get("side_leader", false)) or bool(a.flags.get("captain", false))


static func status_of(a: SimActor) -> String:
	## "DOWN" | "SHOOK" | "STAGGERED" | "" — DOWN and SHOOK are Dunk
	## Finisher windows on street enemies.
	if bool(a.flags.get("knocked", false)) or bool(a.flags.get("downed", false)):
		return "DOWN"
	if a.is_shook():
		return "SHOOK"
	if a.is_broken():
		return "STAGGERED"
	return ""


static func finisher_open(a: SimActor) -> bool:
	return status_of(a) in ["DOWN", "SHOOK"]


static func should_show(a: SimActor, since_hit_s: float, dist_m: float) -> bool:
	if a == null or not a.alive or not is_street_hostile(a):
		return false
	if since_hit_s <= SHOW_AFTER_HIT_S or status_of(a) != "":
		return true
	return is_named(a) and dist_m <= NAMED_RANGE_M


func _draw_bars() -> void:
	if game == null or game.sim == null or game.player == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var font: Font = UIFonts.body()
	for a: SimActor in game.sim.actors:
		var since: float = float(_hit_t.get(a.id, 99.0))
		if not should_show(a, since, a.dist_to(game.player)):
			continue
		var base: Vector3 = (game.views[a.id] as Node3D).global_position if game.views.has(a.id) else a.pos
		var wp: Vector3 = base + Vector3(0, (a.height * 0.45 if status_of(a) == "DOWN" else a.height) + 0.45, 0)
		if cam.is_position_behind(wp):
			continue
		var p: Vector2 = cam.unproject_position(wp)
		_draw_one(a, p, since, font)


func _draw_one(a: SimActor, p: Vector2, since: float, font: Font) -> void:
	var w: float = BAR_W * (1.35 if is_named(a) else 1.0)
	var r: Rect2 = Rect2(p - Vector2(w * 0.5, BAR_H * 0.5), Vector2(w, BAR_H))
	var hp_r: float = clampf(a.hp / maxf(1.0, a.hp_max), 0.0, 1.0)
	var chip: float = maxf(hp_r, float(_chip.get(a.id, hp_r)))
	var jolt: float = maxf(0.0, 1.0 - since * 6.0) * 3.0   # bar shakes on the hit
	r.position.x += sin(_clock * 90.0) * jolt
	_canvas.draw_rect(r.grow(3.0), Color(0.04, 0.04, 0.06, 0.85))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * chip, r.size.y)), Color(1, 1, 1, 0.9))
	var fill: Color = Color("#FF4A4A")
	var status: String = status_of(a)
	if status != "":
		fill = Color("#FFE040").lerp(Color("#FFFFFF"), 0.5 + 0.5 * sin(_clock * 12.0))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * hp_r, r.size.y)), fill)
	if is_named(a) and a.display_name != "":
		_canvas.draw_string_outline(font, Vector2(r.position.x - 30.0, r.position.y - 8.0), a.display_name, HORIZONTAL_ALIGNMENT_CENTER, w + 60.0, 24, 8, Color(0.04, 0.04, 0.06))
		_canvas.draw_string(font, Vector2(r.position.x - 30.0, r.position.y - 8.0), a.display_name, HORIZONTAL_ALIGNMENT_CENTER, w + 60.0, 24, Color("#F2F6FF"))
	if status != "":
		var tag: String = status
		if finisher_open(a) and game.player.has_ball and a.dist_to(game.player) <= 6.0:
			tag = "[%s] FINISH" % InputPrompts.key("interact")
		var ty: float = r.end.y + 32.0
		var col: Color = Color("#FFE040") if finisher_open(a) else Color("#FF9A3E")
		_canvas.draw_string_outline(font, Vector2(r.position.x - 40.0, ty), tag, HORIZONTAL_ALIGNMENT_CENTER, w + 80.0, 32, 10, Color(0.04, 0.04, 0.06))
		_canvas.draw_string(font, Vector2(r.position.x - 40.0, ty), tag, HORIZONTAL_ALIGNMENT_CENTER, w + 80.0, 32, col)
