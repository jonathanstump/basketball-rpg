extends Node
## Logical asset IDs -> procedural builders or imported scenes (spec D4).
## Real models drop in later by registering a scene path for the same ID.

var _builders: Dictionary = {}   # id -> Callable returning Node3D
var _scenes: Dictionary = {}     # id -> res:// path to a PackedScene


func register_builder(id: String, builder: Callable) -> void:
	_builders[id] = builder


func register_scene(id: String, path: String) -> void:
	_scenes[id] = path


func has_asset(id: String) -> bool:
	return _scenes.has(id) or _builders.has(id)


func build(id: String) -> Node3D:
	if _scenes.has(id) and ResourceLoader.exists(str(_scenes[id])):
		var ps: PackedScene = load(str(_scenes[id]))
		return ps.instantiate() as Node3D
	if _builders.has(id):
		var c: Callable = _builders[id]
		return c.call() as Node3D
	push_warning("AssetRegistry: no asset for '%s'" % id)
	var n: Node3D = Node3D.new()
	n.name = "Missing_" + id
	return n


func _exit_tree() -> void:
	## Static caches hold shared resources; release them before engine
	## shutdown so exit is clean (no "resources still in use").
	ToonMaterials.clear_cache()
	MeshLib.clear_cache()
	PoseLibrary.clear_cache()
	_builders.clear()
