extends Node
## Dev console (spec §15.15). Backtick toggles it in debug builds. Systems
## register commands; tests call execute() directly.

var commands: Dictionary = {}   # name -> {callable, help}
var history: PackedStringArray = PackedStringArray()
var god_mode: bool = false
var one_hit: bool = false
var _layer: CanvasLayer = null
var _edit: LineEdit = null
var _log: Label = null


func _ready() -> void:
	register("help", _cmd_help, "list commands")
	register("god", func(_a: PackedStringArray) -> String:
		god_mode = not god_mode
		return "god %s" % god_mode, "toggle invulnerability")
	register("onehit", func(_a: PackedStringArray) -> String:
		one_hit = not one_hit
		return "onehit %s" % one_hit, "toggle one-hit kills")
	register("timescale", func(a: PackedStringArray) -> String:
		Engine.time_scale = float(a[0]) if a.size() > 0 else 1.0
		return "timescale %s" % Engine.time_scale, "set Engine.time_scale")
	register("set_rep", func(a: PackedStringArray) -> String:
		GameState.rep = int(a[0]) if a.size() > 0 else 0
		return "rep %d" % GameState.rep, "set Rep")
	register("tier", func(a: PackedStringArray) -> String:
		return "%s tier %d" % [a[0] if a.size() > 0 else "?", TierManager.tier_of(a[0]) if a.size() > 0 else 0], "show tier of a region")
	register("start", func(a: PackedStringArray) -> String:
		GameState.new_run(GameState.archetype, a[0] if a.size() > 0 else "brooklyn")
		return "new run from %s" % GameState.start_borough, "start a run from a borough")
	register("crown", func(a: PackedStringArray) -> String:
		if a.size() > 0:
			GameState.award_crown(a[0])
		return "crowns %s" % GameState.crowns, "award a Crown")


	var qa_id: String = qa_arg()
	if qa_id != "":
		call_deferred("_start_qa", qa_id)


static func qa_arg() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--qa-run="):
			return a.trim_prefix("--qa-run=")
	return ""


func _start_qa(id: String) -> void:
	var runner_script: GDScript = load("res://tools/qa_runner.gd")
	var runner: Node = runner_script.new()
	runner.set("script_id", id)
	add_child(runner)


func register(name: String, c: Callable, help: String = "") -> void:
	commands[name] = {"callable": c, "help": help}


func execute(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var name: String = parts[0]
	history.append(line)
	if not commands.has(name):
		return "unknown command: " + name
	var entry: Dictionary = commands[name]
	var c: Callable = entry["callable"]
	return str(c.call(parts.slice(1)))


func _cmd_help(_a: PackedStringArray) -> String:
	var names: Array = commands.keys()
	names.sort()
	return ", ".join(PackedStringArray(names))


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_console"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 100
		var box: VBoxContainer = VBoxContainer.new()
		box.position = Vector2(16, 16)
		box.custom_minimum_size = Vector2(900, 0)
		_log = Label.new()
		_edit = LineEdit.new()
		_edit.placeholder_text = "command (help)"
		_edit.text_submitted.connect(func(t: String) -> void:
			_log.text = execute(t)
			_edit.clear())
		box.add_child(_log)
		box.add_child(_edit)
		_layer.add_child(box)
		add_child(_layer)
		_layer.visible = false
	_layer.visible = not _layer.visible
	if _layer.visible:
		_edit.grab_focus()
