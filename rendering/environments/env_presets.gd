class_name EnvPresets
extends RefCounted
## Builds one WorldEnvironment preset per region (spec §12.5, §15.12) from
## data/environments.json, then applies the active quality preset.

const SKY_SHADER: Shader = preload("res://rendering/shaders/night_sky.gdshader")


static func preset(id: String) -> Dictionary:
	var d: Dictionary = DataDB.item("environments", id)
	return d if not d.is_empty() else DataDB.item("environments", "brooklyn")


static func build(id: String, quality: String = "") -> Environment:
	var p: Dictionary = preset(id)
	var env: Environment = Environment.new()
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("top_color", JU.color(p.get("sky_top")))
	sky_mat.set_shader_parameter("horizon_color", JU.color(p.get("sky_horizon")))
	sky_mat.set_shader_parameter("glow_color", JU.color(p.get("horizon_glow")))
	sky_mat.set_shader_parameter("glow_strength", JU.f(p, "glow_strength", 0.6))
	sky_mat.set_shader_parameter("stars", 0.0 if id == "dawn" or id == "interior" else 0.6)
	sky_mat.set_shader_parameter("moon_size", 0.0 if id == "dawn" or id == "garden" else 0.035)
	sky_mat.set_shader_parameter("sun_color", JU.color(p.get("sun", "#000000"), Color.BLACK))
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = JU.color(p.get("ambient"))
	env.ambient_light_energy = JU.f(p, "ambient_energy", 0.5)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = JU.f(p, "exposure", 1.0)
	env.fog_enabled = JU.f(p, "fog_density") > 0.0
	env.fog_light_color = JU.color(p.get("fog_color"))
	env.fog_density = JU.f(p, "fog_density", 0.01)
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = JU.f(p, "glow_intensity", 0.9)
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = JU.f(p, "saturation", 1.1)
	env.adjustment_contrast = 1.08
	apply_quality(env, quality if quality != "" else Settings.get_string("quality"))
	return env


static func quality_preset(q: String) -> Dictionary:
	var presets: Dictionary = JU.dict(DataDB.tuning("quality"), "presets")
	return JU.dict(presets, q) if presets.has(q) else JU.dict(presets, "high")


static func apply_quality(env: Environment, q: String) -> void:
	var qp: Dictionary = quality_preset(q)
	env.ssr_enabled = JU.b(qp, "ssr")
	env.ssr_max_steps = 48
	env.volumetric_fog_enabled = JU.b(qp, "volumetric_fog")
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = env.fog_light_color
	env.glow_enabled = JU.b(qp, "glow", true)


static func apply_viewport(vp: Viewport, q: String) -> void:
	## Viewport-level parts of a quality preset (MSAA, 3D scale, shadow atlas).
	var qp: Dictionary = quality_preset(q)
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(JU.i(qp, "msaa"), 0, 2)]
	vp.scaling_3d_scale = JU.f(qp, "scale_3d", 1.0)
	vp.positional_shadow_atlas_size = JU.i(qp, "shadow_atlas", 4096)
	RenderingServer.directional_shadow_atlas_set_size(JU.i(qp, "dir_shadow", 2048), true)


static func auto_quality() -> String:
	## Deck preset is auto-selected on Steam Deck (spec §15.17, M14).
	return "deck" if SteamService.is_on_steam_deck() else Settings.get_string("quality")


static func rim_tint(id: String) -> Color:
	return JU.color(preset(id).get("rim"), Color(1, 0.7, 0.45))


static func moon_light(id: String) -> DirectionalLight3D:
	var p: Dictionary = preset(id)
	var l: DirectionalLight3D = DirectionalLight3D.new()
	l.name = "MoonLight"
	l.light_color = JU.color(p.get("moon_light"))
	l.light_energy = JU.f(p, "moon_energy", 0.25)
	l.shadow_enabled = l.light_energy > 0.2
	## Top-down camera: only nearby casters matter (draw-call budget, §15.17).
	l.directional_shadow_max_distance = 45.0
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	l.rotation_degrees = Vector3(-72, 30, 0)
	return l
