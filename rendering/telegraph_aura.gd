class_name TelegraphAura
extends MeshInstance3D
## "About to attack" cue (spec §7.5, §8.1): a red glow above a hostile's head
## that swells through the wind-up and pulses bright in the last frames
## before the hit (the moment to dodge for an ankle-breaker or press Hands Up
## for a strip). Unblockable attacks glow larger with a white core and
## flicker (steady when "Reduce flashes" is on). Reads Telegraph only.

const RED: Color = Color(1.0, 0.12, 0.08)
const SIZE_M: float = 0.9

var actor: SimActor
var _mat: StandardMaterial3D
var _t: float = 0.0
var _shown: float = 0.0   # smoothed visibility so the glow fades in and out


static func create(a: SimActor) -> TelegraphAura:
	var aura: TelegraphAura = TelegraphAura.new()
	aura.actor = a
	aura.name = "TelegraphAura"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(SIZE_M, SIZE_M)
	aura.mesh = q
	aura._mat = StandardMaterial3D.new()
	aura._mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura._mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura._mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	aura._mat.no_depth_test = false
	aura._mat.render_priority = 2
	aura._mat.albedo_texture = _glow_texture()
	aura._mat.albedo_color = Color(RED, 0.0)
	aura.material_override = aura._mat
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	return aura


static func _glow_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


static func strength(info: Dictionary, t: float, reduce_flashes: bool) -> float:
	## 0..~1.6: swell with progress, then a bright pulse in the cue frames.
	if info.is_empty():
		return 0.0
	var s: float = lerpf(0.35, 0.8, float(info["progress"]))
	if bool(info["now"]):
		s = 1.3
		if bool(info["unblockable"]) and not reduce_flashes:
			s += 0.3 * (0.5 + 0.5 * sin(t * 40.0))
	return s


func update_aura(delta: float, head_y: float) -> void:
	_t += delta
	var info: Dictionary = Telegraph.read(actor)
	var want: float = strength(info, _t, Settings.get_bool("reduce_flashes"))
	_shown = move_toward(_shown, want, delta * 8.0)
	visible = _shown > 0.02
	if not visible:
		return
	var unblock: bool = bool(info.get("unblockable", false))
	position = Vector3(0, head_y + 0.25, 0)
	scale = Vector3.ONE * (0.6 + 0.5 * _shown) * (1.35 if unblock else 1.0)
	var core: Color = RED.lerp(Color.WHITE, 0.45) if unblock and bool(info.get("now", false)) else RED
	_mat.albedo_color = Color(core, clampf(_shown, 0.0, 1.0))
