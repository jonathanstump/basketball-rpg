class_name DistrictSideStreet
extends RefCounted
## Runs a district's side street (SideStreets plan): spawns the crew at the
## dead end, plays the leader's line when they spot you, and when the whole
## crew is down marks it cleared, drops the alley's loot and earns Buzz.

var d: District
var plan: Dictionary = {}
var crew_ids: Array[int] = []
var _intro_done: bool = false


func _init(district: District, side_plan: Dictionary) -> void:
	d = district
	plan = side_plan


func spawn() -> void:
	if plan.is_empty() or SideStreets.is_cleared(d.district_id):
		return
	var ld: Dictionary = JU.dict(JU.dict(plan, "leader"), "data")
	var leader: SimActor = d.spawner.add(JU.s(ld, "enemy", "big_man"), JU.dict(plan, "leader")["pos"], d.tier,
		{"captain": true, "no_respawn": true, "facing": float(d.district_id.hash() % 628) / 100.0})
	if leader != null:
		leader.flags["side_crew"] = true
		leader.flags["side_leader"] = true
		leader.display_name = "%s, %s" % [JU.s(ld, "name"), JU.s(ld, "title")]
		crew_ids.append(leader.id)
	for c: Variant in JU.a(plan, "crew"):
		var cd: Dictionary = c
		var a: SimActor = d.spawner.add(JU.s(cd, "enemy"), cd["pos"], d.tier, {"no_respawn": true, "facing": float(crew_ids.size()) * 1.7})
		if a != null:
			a.flags["side_crew"] = true
			crew_ids.append(a.id)


func on_event(t: String, a: SimActor) -> void:
	if a == null or not crew_ids.has(a.id):
		return
	var e: Dictionary = SideStreets.entry(d.district_id)
	if t == "enemy_alerted" and not _intro_done:
		_intro_done = true
		EventBus.popup_text.emit(JU.s(plan, "name").to_upper(), a.pos, "style")
		EventBus.dialogue_requested.emit(JU.s(JU.dict(e, "leader"), "name"), JU.strs(e, "intro"))
	elif t == "actor_killed" and remaining() == 0 and not SideStreets.is_cleared(d.district_id):
		_clear(e, a.pos)


func remaining() -> int:
	var n: int = 0
	for id: int in crew_ids:
		var o: SimActor = d.sim.actor_by_id(id)
		if o != null and o.alive:
			n += 1
	return n


func _clear(e: Dictionary, at: Vector3) -> void:
	GameState.set_flag(SideStreets.cleared_flag(d.district_id))
	EventBus.popup_text.emit("%s CLEARED" % JU.s(plan, "name").to_upper(), at, "style")
	EventBus.dialogue_requested.emit(JU.s(JU.dict(e, "leader"), "name"), JU.strs(e, "defeat"))
	DistrictActions.drop_loot(d, JU.s(plan, "pool", "retail"), at)
	DistrictBuzz.earn(d, "side_street_cleared", "side_" + d.district_id, at)
	var npc: Dictionary = d.interact.find("side_npc_" + d.district_id)
	if not npc.is_empty():
		(npc["data"] as Dictionary)["lines"] = JU.strs(JU.dict(e, "npc"), "after")
	SaveSystem.request_autosave()
