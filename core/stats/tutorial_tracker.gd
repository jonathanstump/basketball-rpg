class_name TutorialTracker
extends RefCounted
## "I Got Next" tutorial steps (spec §3.3), data in dialogue/prologue.json.
## Steps can complete in any order (players poke at things); the prompt
## always shows the first one still open. Pure: fed sim events + facts.

const BACKPEDAL_FRAMES: int = 30   # lock-on step: half a second backing up while locked

var steps: Array = []
var done: Dictionary = {}
var player_id: int = 0
var backpedal_frames: int = 0


func _init(pid: int) -> void:
	player_id = pid
	steps = JU.a(DataDB.get_dict("dialogue/prologue"), "steps")


func mark(key: String) -> void:
	for s: Variant in steps:
		if JU.s(s as Dictionary, "done") == key:
			done[JU.s(s as Dictionary, "id")] = true


func current() -> Dictionary:
	for s: Variant in steps:
		if not done.has(JU.s(s as Dictionary, "id")):
			return s
	return {}


func current_id() -> String:
	return JU.s(current(), "id")


func is_done(id: String) -> bool:
	return done.has(id)


func tutorial_complete() -> bool:
	## Every teaching step done (the cameo is the scene's own beat).
	for s: Variant in steps:
		var id: String = JU.s(s as Dictionary, "id")
		if id != "cameo" and not done.has(id):
			return false
	return true


func feed_lock(locked: bool, to_target: Vector3, vel: Vector3) -> void:
	## Lock-on step (revision 17): locked onto someone and backing away from
	## them (you keep facing them while you do).
	var flat: Vector3 = Vector3(vel.x, 0.0, vel.z)
	var to: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	if locked and flat.length() > 1.0 and to.length() > 0.01 and flat.normalized().dot(to.normalized()) < -0.5:
		backpedal_frames += 1
	if backpedal_frames >= BACKPEDAL_FRAMES:
		mark("lock_backpedal")


func feed(ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	var who: int = int(ev.get("actor", ev.get("attacker", 0)))
	match t:
		"hit_resolved":
			var r: String = str(ev["result"])
			if int(ev["attacker"]) == player_id and r == "hit":
				mark("strike")
			if r == "ankle_breaker" and (int(ev["target"]) == player_id or int(ev["attacker"]) == player_id):
				mark("ankle_breaker")
			if r == "strip" and (int(ev["target"]) == player_id or int(ev["attacker"]) == player_id):
				mark("strip")
		"action_started":
			if who == player_id and str(ev["move"]) in ["crossover", "stepback"]:
				mark("crossover")
		"shot_made":
			if who == player_id and str(ev.get("hoop_kind", "")) == "crate":
				mark("crate_make")
		"steal":
			if who == player_id:
				mark("strip")
		"qw_used":
			if who == player_id:
				mark("qw_used")
