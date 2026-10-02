class_name MenuKit
extends RefCounted
## Helpers for the sticker-style list menus: open a ListMenu on a GameWorld
## and describe items/effects in plain words.

const EFFECT_NAMES: Dictionary = {
	"speed_mult": "Speed", "poise_add": "Poise", "poise_mult": "Poise", "dodge_dist_mult": "Dodge distance",
	"jump_add": "Jump (m)", "jump_mult": "Jump", "dunk_range_mult": "Dunk range", "parry_frames_add": "Parry frames",
	"dr_add": "Damage reduction", "perfect_add": "Perfect width", "dodge_wind_mult": "Dodge Wind cost",
	"taunt_hype_mult": "Taunt Hype", "ball_security_add": "Ball security", "damage_mult": "Damage", "crit_add": "Crit chance",
	"hype_gain_mult": "Hype gain", "dribble_damage_mult": "Dribble damage", "dunk_damage_mult": "Dunk damage",
	"gather_mult": "Gather time", "burn_resist_add": "Burn resist", "wind_regen_mult": "Wind regen", "steal_add": "Steal chance",
	"rep_mult": "Rep", "heart_mult": "Heart", "hype_decay_mult": "Hype decay", "tokens_mult": "Tokens", "qw_heal_add": "Quarter Water heal",
	"enemy_leash_mult": "Enemy leash range", "status_resist_add": "Status resist", "push_resist_add": "Push resist",
	"recovery_frames_add": "Recovery frames", "stat_all_add": "All stats", "all_mult": "Everything", "ankle_frames_add": "Ankle-breaker frames",
}


static func show(w: Node, title: String, opts: Array[Dictionary], handler: Callable, footer: String = "") -> ListMenu:
	## Opens on any host with open_menu(m)/close_menu() (GameWorld, title, creator).
	var m: ListMenu = ListMenu.new()
	m.set_options(title, opts, footer if footer != "" else "Tokens: %d   Rep: %d" % [GameState.tokens, GameState.rep])
	m.chosen.connect(handler)
	m.cancelled.connect(Callable(w, "close_menu"))
	w.call("open_menu", m)
	return m


static func effects_text(effects: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in effects.keys():
		var key: String = str(k)
		var v: float = float(effects[k])
		var label: String = str(EFFECT_NAMES.get(key, key.replace("_", " ")))
		if key.ends_with("_mult") or key in ["dr_add", "crit_add", "steal_add", "status_resist_add", "qw_heal_add", "ball_security_add", "burn_resist_add", "push_resist_add"]:
			parts.append("%s %+d%%" % [label, int(round(v * 100.0))])
		elif key == "perfect_add":
			parts.append("%s %+.3f" % [label, v])
		else:
			parts.append("%s %+s" % [label, str(snappedf(v, 0.01))])
	return ", ".join(parts)


static func item_detail(id: String) -> String:
	var it: Dictionary = DataDB.find_any(id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  [%s]" % [JU.s(it, "name", id), JU.s(it, "rarity", "").to_upper()])
	if it.has("effects"):
		lines.append(effects_text(JU.dict(it, "effects")))
	if DataDB.has_item("balls", id):
		var sc: Dictionary = JU.dict(it, "scaling")
		var grades: PackedStringArray = PackedStringArray()
		for s: Variant in sc.keys():
			grades.append("%s %s" % [str(s).substr(0, 3).to_upper(), sc[s]])
		lines.append("Attack %d   Scaling %s   Gather %.2fs   +%d" % [JU.i(it, "attack"), " ".join(grades), JU.f(it, "gather_s"), int(GameState.ball_upgrades.get(id, 0))])
	if it.has("description"):
		lines.append(JU.s(it, "description"))
	lines.append(JU.s(it, "flavor"))
	return "\n".join(lines)
