extends GameWorld
## M4 enemy lab: every street archetype, critter, unique and special laid out
## in rows on a block (Tier from the `lab_tier` export) so each can be fought.

@export var lab_tier: int = 1

const ROWS: Array = [
	["ball_hog", "showboat", "big_man", "sniper", "hype_man", "pickpocket"],
	["pigeon", "rat", "pizza_rat", "gull", "night_deer", "bootleg"],
	["breaker", "fixie_rider", "juggler", "pigeon_keeper", "suit", "big_head_mascot", "tourist"],
]


func _ready() -> void:
	setup_world("brooklyn")
	sim.collision.set_bounds(Vector2(-60, -60), Vector2(60, 60))
	KitProps.ground_tile(level_root, Vector3.ZERO, Vector2(120, 120), ToonMaterials.asphalt())
	for x: float in [-30.0, 0.0, 30.0]:
		KitProps.streetlight(level_root, sim.collision, Vector3(x, 0, -6), Vector3(0, 0, 1))
	for r: int in ROWS.size():
		var row: Array = ROWS[r]
		for i: int in row.size():
			var pos: Vector3 = Vector3(-30.0 + float(i) * 10.0, 0, -20.0 - float(r) * 14.0)
			spawner.add(str(row[i]), pos, lab_tier, {"facing": 0.0, "captain": r == 0 and i == 0})
	spawn_player(Vector3(0, 0, 10))
	camera_rig.snap()


func setup_render_smoke(entry: Dictionary) -> void:
	if JU.s(entry, "mode") == "overview":
		ready.connect(func() -> void:
			player.pos = Vector3(-10, 0, -22)
			camera_rig.snap())
