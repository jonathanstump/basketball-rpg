extends Node
## Smoke: ball_lab with scripted input — perfect jumper, chest pass at a
## dummy (ricochet back), crate-hoop make in combat (Bucket Blast).

var lab: GameWorld
var seen: Dictionary = {}


func _ready() -> void:
	lab = (load("res://world/labs/ball_lab.tscn") as PackedScene).instantiate() as GameWorld
	add_child(lab)
	var si: ScriptedInput = ScriptedInput.new()
	# Jumper from 7 m (mid zone): hold so the release lands at ~0.82.
	si.hold(5, 30, "shoot")
	# Turn toward the right dummy and chest pass.
	si.move_at(120, Vector2(0.45, -0.9)).move_at(127, Vector2.ZERO).press_at(130, "heavy")
	# Walk to the left crate hoop and shoot.
	si.move_at(200, Vector2(-1, 0)).move_at(290, Vector2.ZERO).hold(300, 325, "shoot")
	lab.use_scripted_input(si)
	lab.sim.sim_event.connect(func(ev: Dictionary) -> void: seen[str(ev["type"])] = true)
	lab.sim_stepped.connect(_on_step)


func _on_step(frame: int) -> void:
	if frame != 460:
		return
	var problems: PackedStringArray = PackedStringArray()
	for t: String in ["shot_released", "shot_made", "pass_hit", "pass_returned", "bucket_blast"]:
		if not seen.has(t):
			problems.append("missing event " + t)
	if lab.presenter.ball_views.is_empty():
		problems.append("no ball view")
	if problems.is_empty():
		print("SMOKE OK ball_lab_smoke")
	else:
		for p: String in problems:
			push_error("ball_lab_smoke: " + p)
		print("seen: ", seen.keys())
	get_tree().quit()
