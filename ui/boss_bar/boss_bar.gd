class_name BossBar
extends Control
## Boss HUD (spec §9.1, §14): bottom-center name in graffiti type + title,
## Heart bar, Composure bar under it; duel banner (CHECK, GAME POINT, TAKE
## IT BACK) and the clear-the-ball hint.

var boss: SimActor = null
var duel: PossessionDuel = null
var rules: BossDuelRules = null     # R7 meters: your ball security, theirs
var title: String = ""
var banner: String = ""
var _banner_t: float = 0.0
var _ghost: float = 1.0
var _name: Label
var _title: Label
var _banner: Label
var _hint: Label
var _poss: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = _mk(UIFonts.graffiti(), 44, Vector2(560, 902), Color("#F2F6FF"))
	_title = _mk(UIFonts.title(), 18, Vector2(560, 952), Color("#F4B400"))
	_banner = _mk(UIFonts.graffiti(), 96, Vector2(360, 300), Color("#FF3EA5"))
	_banner.size = Vector2(1200, 140)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _mk(UIFonts.title(), 22, Vector2(660, 840), Color("#F4B400"))
	_hint.size = Vector2(600, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_poss = _mk(UIFonts.title(), 26, Vector2(460, 120), Color.WHITE)
	_poss.size = Vector2(1000, 40)
	_poss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _mk(font: Font, size_px: int, pos: Vector2, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 12)
	l.position = pos
	l.size = Vector2(800, size_px + 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func show_banner(text: String, seconds: float = 1.4) -> void:
	banner = tr(text)
	_banner_t = seconds


func _process(delta: float) -> void:
	visible = boss != null
	if boss == null:
		return
	_name.text = tr(boss.display_name)
	_title.text = tr(title)
	_banner_t -= delta
	_banner.text = banner if _banner_t > 0.0 else ""
	_banner.scale = Vector2.ONE * (1.0 + maxf(0.0, _banner_t - 1.0) * 0.6)
	var hint: String = ""
	if duel != null and duel.state == PossessionDuel.PLAYER_OFFENSE and not duel.player_cleared:
		hint = tr("CLEAR IT - TAKE IT PAST THE ARC")
	_hint.text = hint
	var pl: Array = possession_line(duel.state if duel != null else "")
	_poss.text = tr(str(pl[0]))
	_poss.add_theme_color_override("font_color", pl[1] as Color)
	_ghost = lerpf(_ghost, boss.hp / maxf(1.0, boss.hp_max), clampf(delta * 2.0, 0.0, 1.0))
	queue_redraw()


static func possession_line(state: String) -> Array:
	## R7: always say whose ball it is and what that means for you.
	match state:
		PossessionDuel.PLAYER_OFFENSE:
			return ["YOUR BALL - SCORE ON THEM", Color("#7CFFB2")]
		PossessionDuel.BOSS_OFFENSE:
			return ["THEIR BALL - STRIP IT OR KNOCK IT LOOSE", Color("#FF6A5A")]
		PossessionDuel.LOOSE_BALL:
			return ["LOOSE BALL - GO GET IT", Color("#F4B400")]
		PossessionDuel.GAME_POINT:
			return ["GAME POINT - SCORE TO FINISH IT", Color("#7CFFB2")]
	return ["", Color.WHITE]


func _draw() -> void:
	if boss == null:
		return
	if rules != null and duel != null:
		## Under the possession line: how close the ball is to coming loose.
		var mp: Vector2 = Vector2(760, 166)
		var frac: float = -1.0
		var col2: Color = Color.WHITE
		if duel.state == PossessionDuel.PLAYER_OFFENSE:
			frac = 1.0 - clampf(rules.turnover / maxf(1.0, rules.turnover_limit()), 0.0, 1.0)
			col2 = Color("#7CFFB2")
		elif duel.state == PossessionDuel.BOSS_OFFENSE and boss.has_ball:
			frac = 1.0 - clampf(rules.security / maxf(1.0, rules.security_limit()), 0.0, 1.0)
			col2 = Color("#FF6A5A")
		if frac >= 0.0:
			draw_rect(Rect2(mp - Vector2(3, 3), Vector2(406, 14)), Color("#0B0B10"))
			draw_rect(Rect2(mp, Vector2(400 * frac, 8)), col2)
	var pos: Vector2 = Vector2(560, 990)
	var w: float = 800.0
	draw_rect(Rect2(pos - Vector2(5, 5), Vector2(w + 10, 34)), Color("#0B0B10"))
	draw_rect(Rect2(pos, Vector2(w, 24)), Color("#24242E"))
	draw_rect(Rect2(pos, Vector2(w * clampf(_ghost, 0, 1), 24)), Color(1, 1, 1, 0.4))
	draw_rect(Rect2(pos, Vector2(w * clampf(boss.hp / maxf(1.0, boss.hp_max), 0, 1), 24)), Color("#E8344A"))
	var armor: float = float(boss.flags.get("armor", 0.0))
	if armor > 0.0:
		## King of the Heap's trash armor: a white bar over the Heart bar.
		draw_rect(Rect2(pos, Vector2(w * clampf(armor / maxf(1.0, float(boss.flags.get("armor_max", armor))), 0, 1), 8)), Color("#F2F2F2"))
	if boss.composure != null:
		var cp: Vector2 = pos + Vector2(0, 32)
		draw_rect(Rect2(cp, Vector2(w, 10)), Color("#24242E"))
		var col: Color = Color("#FFE040") if boss.composure.broken != "" else Color("#F4B400")
		draw_rect(Rect2(cp, Vector2(w * boss.composure.ratio(), 10)), col)
