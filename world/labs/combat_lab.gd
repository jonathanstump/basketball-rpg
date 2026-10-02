extends GameWorld
## M3 combat lab: a rec-court with training dummies (passive, attacking, one
## dribbling a ball to strip) and a crate hoop to Bucket Blast them.

var passive: TrainingDummy
var attacker: TrainingDummy
var dribbler: TrainingDummy


func _ready() -> void:
	setup_world("bronx")
	build_lab()
	spawn_player(Vector3(0, 0, 4))
	camera_rig.snap()


func build_lab() -> void:
	sim.collision.set_bounds(Vector2(-25, -25), Vector2(25, 25))
	var hoop: SimHoop = balls.add_hoop(SimHoop.regulation("lab_hoop", Vector3(0, 0, -13.0), Vector3(0, 0, 1)))
	presenter.add_hoop_view(hoop)
	CourtFloor.build(level_root, hoop, Vector2(30, 30), Vector3(0, -0.02, -1), {"floor": "#7A2A30", "key": "#F4B400"})
	KitProps.ground_tile(level_root, Vector3(0, -0.03, 0), Vector2(70, 70), ToonMaterials.asphalt())
	var crate: SimHoop = balls.add_hoop(SimHoop.crate("lab_crate", Vector3(10, 0, 2), Vector3(-1, 0, 0)))
	presenter.add_hoop_view(crate)
	KitProps.streetlight(level_root, sim.collision, Vector3(-11, 0, -4), Vector3(1, 0, 0))
	KitProps.streetlight(level_root, sim.collision, Vector3(11, 0, -8), Vector3(-1, 0, 0))
	passive = add_dummy(Vector3(-4, 0, -2), "passive")
	attacker = add_dummy(Vector3(4, 0, -2), "attack")
	dribbler = add_dummy(Vector3(0, 0, -6), "passive")
	balls.give(balls.spawn_ball("ball_rec", dribbler.actor.pos, dribbler.actor), dribbler.actor)
