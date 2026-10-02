class_name PresenterFx
extends RefCounted
## Juice for sim events (spec §7.14, §13): sound for every hit, make, miss,
## parry and pickup; one-shot impact particles — concrete chips on bosses,
## sparks on crews, feathers on birds.

const SFX: Dictionary = {"shot_released": "shot_release", "ball_picked": "bounce_asphalt", "pass_released": "whoosh", "jumped": "squeak",
	"qw_used": "tokens", "tokens_snatched": "tokens", "on_beat": "perfect", "bucket_damage": "crowd_ooh", "poster": "poster_horn",
	"steal": "strip", "cable_snapped": "rim_clank", "clone_shattered": "chain_ching", "gull_snatch": "whoosh", "fence_shock": "parry",
	"toll_paid": "tokens", "toll_spilled": "tokens", "midnight_unleashed": "poster_horn", "flash_cue": "telegraph"}


static func on_event(game: GameWorld, ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	if SFX.has(t):
		AudioDirector.play_sfx(str(SFX[t]))
	match t:
		"camera_flash":
			EventBus.flash_requested.emit("tourist")
		"arena_event":
			if str(ev.get("event", "")) == "lightning":
				EventBus.flash_requested.emit("lightning")
		"hit_resolved":
			_hit(game, ev)
		"shot_made":
			if str(ev.get("grade", "")) == "PERFECT":
				AudioDirector.play_sfx("perfect")
		"move_started":
			if bool(ev.get("unblockable", false)):
				AudioDirector.play_sfx("telegraph")


static func _hit(game: GameWorld, ev: Dictionary) -> void:
	var r: String = str(ev["result"])
	var tgt: SimActor = game.sim.actor_by_id(int(ev["target"]))
	if tgt == null:
		return
	match r:
		"hit", "guard_break":
			AudioDirector.play_sfx("hit_heavy" if str(ev.get("weight", "")) == "heavy" else "hit_light")
		"guarded", "deflect":
			AudioDirector.play_sfx("parry")
		"strip":
			AudioDirector.play_sfx("strip")
		"ankle_breaker":
			AudioDirector.play_sfx("ankles")
		"rejection":
			AudioDirector.play_sfx("rim_clank")
		_:
			return
	if bool(ev.get("no_flinch", false)):
		return
	var color: Color = Color("#FFD24A")
	var amount: int = 10
	if tgt.kind == "boss" or tgt.kind == "boss_part":
		color = Color("#B8B0A0")
		amount = 18
	elif tgt.archetype in ["pigeon", "gull"] or tgt.archetype.contains("coop"):
		color = Color("#F2F2F2")
	elif tgt.kind == "hooper" and tgt.team == 0:
		color = Color("#FF5A5A")
	burst(game, tgt.pos + Vector3(0, tgt.height * 0.5, 0), color, amount if str(ev.get("weight", "")) != "heavy" else amount * 2)


static func burst(game: GameWorld, at: Vector3, color: Color, amount: int) -> void:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(2, amount)
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	p.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	p.material_override = mat
	p.position = at
	game.add_child(p)
	p.emitting = true
	game.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
