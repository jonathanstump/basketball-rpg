class_name SkylineTowers
extends RefCounted
## Skyscraper shapes for the distant skyline (revision 10). Each tower is a
## few parts — {mesh, pos (base center), size, yaw, tint_k, seed, lit, style}
## — drawn by DistrictSkyline as one MultiMesh per mesh kind:
##   box (walls), cyl (round glass), prism (4-sided pyramid crowns), needle.
## style: 0 windows, 1 glass curtain, 2 lit crown (accent), 3 beacon tip.

const KINDS: PackedStringArray = ["slab", "setback", "crown", "spire", "round", "twin"]


static func pick(mix: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: String in KINDS:
		total += JU.f(mix, k, 1.0 if k == "slab" else 0.0)
	var r: float = rng.randf() * maxf(total, 0.001)
	for k: String in KINDS:
		r -= JU.f(mix, k, 1.0 if k == "slab" else 0.0)
		if r <= 0.0:
			return k
	return "slab"


static func _part(mesh: String, base: Vector3, size: Vector3, yaw: float, rng: RandomNumberGenerator, lit: float, style: int) -> Dictionary:
	return {"mesh": mesh, "pos": base, "size": size, "yaw": yaw, "tint_k": rng.randf(), "seed": rng.randf(), "lit": lit, "style": style}


static func parts(kind: String, base: Vector3, w: float, h: float, d: float, yaw: float, lit: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		"setback":
			## Wedding cake: three tiers stepping in, a lit crown on top.
			var y: float = 0.0
			var k: float = 1.0
			for f: float in [0.55, 0.28, 0.17]:
				out.append(_part("box", base + Vector3(0, y, 0), Vector3(w * k, h * f, d * k), yaw, rng, lit, 0))
				y += h * f
				k *= 0.72
			out.append(_part("prism", base + Vector3(0, y, 0), Vector3(w * k * 1.2, h * 0.08, d * k * 1.2), yaw + PI * 0.25, rng, 0.0, 2))
		"crown":
			## Art deco: a shaft with a stepped, lit crown and a mast.
			out.append(_part("box", base, Vector3(w, h * 0.82, d), yaw, rng, lit, 0))
			out.append(_part("box", base + Vector3(0, h * 0.82, 0), Vector3(w * 0.7, h * 0.08, d * 0.7), yaw, rng, 0.0, 2))
			out.append(_part("prism", base + Vector3(0, h * 0.9, 0), Vector3(w * 0.75, h * 0.14, d * 0.75), yaw + PI * 0.25, rng, 0.0, 2))
			out.append(_part("needle", base + Vector3(0, h * 1.04, 0), Vector3(0.9, h * 0.16, 0.9), yaw, rng, 0.0, 3))
		"spire":
			## Supertall glass with a needle spire and a beacon.
			out.append(_part("box", base, Vector3(w * 0.85, h, d * 0.85), yaw, rng, lit * 0.8, 1))
			out.append(_part("box", base + Vector3(0, h, 0), Vector3(w * 0.55, h * 0.06, d * 0.55), yaw, rng, 0.0, 2))
			out.append(_part("needle", base + Vector3(0, h * 1.06, 0), Vector3(1.2, h * 0.35, 1.2), yaw, rng, 0.0, 3))
		"round":
			out.append(_part("cyl", base, Vector3(w, h, w), yaw, rng, lit, 1))
			out.append(_part("cyl", base + Vector3(0, h, 0), Vector3(w * 0.8, h * 0.04, w * 0.8), yaw, rng, 0.0, 2))
		"twin":
			var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * w * 0.42
			for s: float in [-1.0, 1.0]:
				out.append(_part("box", base + side * s, Vector3(w * 0.38, h, d * 0.6), yaw, rng, lit, 1))
				out.append(_part("box", base + side * s + Vector3(0, h, 0), Vector3(w * 0.3, h * 0.03, d * 0.45), yaw, rng, 0.0, 2))
		_:
			out.append(_part("box", base, Vector3(w, h, d), yaw, rng, lit, 0))
			if rng.randf() < 0.35:
				out.append(_part("needle", base + Vector3(0, h, 0), Vector3(0.6, h * 0.12, 0.6), yaw, rng, 0.0, 3))
	return out
