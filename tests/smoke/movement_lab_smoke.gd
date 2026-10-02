extends Node
## Smoke: movement_lab with scripted input (walk, sprint, dodge, jump onto a
## stoop step). Checks the player moved, sprinted, had i-frames and jumped.

var lab: GameWorld
var saw_iframes: bool = false
var saw_sprint: bool = false
var max_y: float = 0.0


func _ready() -> void:
	lab = (load("res://world/labs/movement_lab.tscn") as PackedScene).instantiate() as GameWorld
	lab.set("auto_capture_mouse", false)
	add_child(lab)
	var si: ScriptedInput = ScriptedInput.new()
	si.move_at(0, Vector2(1, 0)).hold(20, 140, "dodge").move_at(150, Vector2(-1, 0)).press_at(160, "dodge")
	si.press_at(200, "jump").move_at(230, Vector2(0, -1)).press_at(260, "lock_on")
	lab.use_scripted_input(si)
	lab.sim_stepped.connect(_on_step)


func _on_step(frame: int) -> void:
	var p: SimActor = lab.player
	saw_iframes = saw_iframes or p.invulnerable
	saw_sprint = saw_sprint or lab.player_hooper.sprinting
	max_y = maxf(max_y, p.pos.y)
	if frame == 320:
		_finish()


func _finish() -> void:
	var problems: PackedStringArray = PackedStringArray()
	if lab.player.pos.distance_to(Vector3(0, 0, 4)) < 3.0:
		problems.append("player barely moved")
	if not saw_iframes:
		problems.append("no i-frames seen")
	if not saw_sprint:
		problems.append("never sprinted")
	if max_y < 0.8:
		problems.append("never jumped (max y %.2f)" % max_y)
	if lab.camera_rig.global_position.distance_to(lab.player.pos) > 16.0:
		problems.append("camera not following")
	if problems.is_empty():
		print("SMOKE OK movement_lab_smoke")
	else:
		for p: String in problems:
			push_error("movement_lab_smoke: " + p)
	get_tree().quit()
