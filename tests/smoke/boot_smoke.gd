extends Node
## Smoke: boots every autoload, validates data, instantiates the entry scene.

const AUTOLOADS: PackedStringArray = ["EventBus", "DataDB", "Settings", "GameState", "TierManager",
	"SaveSystem", "AssetRegistry", "InputRouter", "AudioDirector", "SceneRouter", "SteamService", "DebugConsole"]


func _ready() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for a: String in AUTOLOADS:
		if get_tree().root.get_node_or_null(a) == null:
			problems.append("missing autoload " + a)
	problems.append_array(DataDB.validate())
	var boot: Node = (load("res://ui/title/boot.tscn") as PackedScene).instantiate()
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_run("slasher", "bronx")
	if TierManager.tier_of("staten_island") != 5:
		problems.append("tier lookup wrong")
	if problems.is_empty():
		print("SMOKE OK boot_smoke")
	else:
		for p: String in problems:
			push_error("boot_smoke: " + p)
		print("SMOKE FAIL boot_smoke")
	get_tree().quit()
