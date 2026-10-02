class_name BallProps
extends RefCounted
## Applies a ball's data-driven properties (balls.json "props") to the
## holder's flags so systems read them uniformly (spec §10.4).

const PROP_FLAGS: Dictionary = {
	"pass_ricochets": "pass_ricochets",
	"pass_speed_mult": "pass_speed_mult",
	"bucket_blast_radius_mult": "bucket_blast_radius_mult",
	"pass_curve": "pass_homing",
	"wind_cost_mult": "wind_cost_mult",
	"hype_gain_mult": "hype_gain_mult",
	"composure_mult": "composure_mult",
	"physical_mult": "physical_mult",
	"knockdown_chance": "knockdown_chance",
	"crit_bonus": "crit_bonus",
	"takeover_mult": "takeover_mult",
	"unstealable": "unstealable",
	"attack_poise": "attack_poise",
}


static func apply(a: SimActor, item_id: String) -> void:
	for k: String in PROP_FLAGS.values():
		a.flags.erase(k)
	var ball: Dictionary = DataDB.ball(item_id)
	var props: Dictionary = JU.dict(ball, "props")
	for k2: Variant in props.keys():
		if PROP_FLAGS.has(k2):
			a.flags[PROP_FLAGS[k2]] = props[k2]
	a.flags["ball_item"] = item_id
	a.flags["ball_attack"] = JU.f(ball, "attack", 20.0)
