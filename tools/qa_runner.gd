extends Node
## QA runner (spec §15.15). Started by DebugConsole when the game is launched
## with `-- --qa-run=<id>`; runs res://tests/qa/qa_<id>.gd and prints
## `QA PASS <id>` or `QA FAIL <id>: <reason>`, then quits.

var script_id: String = ""
var timeout_s: float = 600.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path: String = "res://tests/qa/qa_%s.gd" % script_id
	if not ResourceLoader.exists(path):
		_finish(false, "no QA script at " + path)
		return
	var scr: GDScript = load(path)
	var qa: QAScript = scr.new()
	qa.name = "QA_" + script_id
	add_child(qa)
	var timer: SceneTreeTimer = get_tree().create_timer(timeout_s, true, false, true)
	timer.timeout.connect(func() -> void: _finish(false, "timeout after %ds" % int(timeout_s)))
	var ok: bool = await qa.run()
	_finish(ok, qa.failure)


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print("QA PASS %s" % script_id)
	else:
		print("QA FAIL %s: %s" % [script_id, reason])
	Engine.time_scale = 1.0
	get_tree().quit(0 if ok else 1)
