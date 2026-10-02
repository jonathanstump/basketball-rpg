class_name BossGating
extends RefCounted
## Phase/tier gating (spec §9.1): T1 phase 1 base moves only; T2 adds (T2)
## moves; T3-4 phase 2 at 50%; T5+ phase 2 plus the T5 event at 25%;
## City (T6) and Garden (T7) get everything.


static func phases(boss: Dictionary, tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in JU.a(boss, "phases"):
		var pd: Dictionary = p
		if JU.i(pd, "min_tier", 1) <= tier:
			out.append(pd)
	return out


static func phase_count(boss: Dictionary, tier: int) -> int:
	return phases(boss, tier).size()


static func moves_for_phase(boss: Dictionary, phase_index: int, tier: int) -> Array[Dictionary]:
	## Move dicts for a phase (1-based), filtered by min_tier.
	var ps: Array[Dictionary] = phases(boss, tier)
	var out: Array[Dictionary] = []
	if phase_index < 1 or phase_index > ps.size():
		return out
	var owner: String = JU.s(boss, "id")
	for id: String in JU.strs(ps[phase_index - 1], "moves"):
		var m: Dictionary = move_ref(owner, id)
		if m.is_empty():
			m = DataDB.move(JU.s(boss, "borrow_from", owner), id)
		if not m.is_empty() and JU.i(m, "min_tier", 1) <= tier:
			out.append(m)
	return out


static func move_ref(owner: String, ref: String) -> Dictionary:
	## "move_id" (the boss's own) or "other_boss:move_id" (borrowed, e.g.
	## Midnight's Prime phase using every King's signature move).
	if ref.contains(":"):
		var parts: PackedStringArray = ref.split(":")
		return DataDB.move(parts[0], parts[1])
	return DataDB.move(owner, ref)


static func phase_threshold(boss: Dictionary, phase_index: int, tier: int) -> float:
	## HP ratio at which `phase_index` begins (phase 1 = 1.0).
	var ps: Array[Dictionary] = phases(boss, tier)
	if phase_index <= 1 or phase_index > ps.size():
		return 1.0
	return JU.f(ps[phase_index - 1], "at_hp_pct", 0.5)


static func t5_event(boss: Dictionary, tier: int) -> Dictionary:
	var ev: Dictionary = JU.dict(boss, "t5_event")
	if ev.is_empty() or tier < JU.i(ev, "min_tier", 5):
		return {}
	return ev


static func base_stats(boss: Dictionary) -> Dictionary:
	## Heart/composure/contest from tuning by kind (mini/king/landmark/final),
	## overridden by the boss file's "base".
	var t: Dictionary = DataDB.tuning("bosses")
	var kind: String = JU.s(boss, "kind", "mini")
	var src: Dictionary = JU.dict(t, "king" if kind in ["king", "landmark", "final", "superboss"] else "mini")
	var out: Dictionary = src.duplicate()
	var base: Dictionary = JU.dict(boss, "base")
	for k: Variant in base.keys():
		out[k] = base[k]
	return out
