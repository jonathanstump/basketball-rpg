class_name ToonMaterials
extends RefCounted
## Cached material factory for the "Toybox Night" look (spec §12, §15.12).
## Materials are shared by key so repeated props batch well.

const TOON: Shader = preload("res://rendering/shaders/toon.gdshader")
const OUTLINE: Shader = preload("res://rendering/shaders/outline.gdshader")
const WINDOWS: Shader = preload("res://rendering/shaders/window_lights.gdshader")
const ASPHALT: Shader = preload("res://rendering/shaders/wet_asphalt.gdshader")
const NEON: Shader = preload("res://rendering/shaders/neon.gdshader")

static var _cache: Dictionary = {}


static func toon(color: Color, outline: bool = true, occludable: bool = false, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> ShaderMaterial:
	var key: String = "toon|%s|%s|%s|%s|%s" % [color.to_html(), outline, occludable, emission.to_html(), emission_energy]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("occludable", occludable)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	if outline:
		m.next_pass = outline_mat(0.012, occludable)
	_cache[key] = m
	return m


static func outline_mat(width: float, occludable: bool = false) -> ShaderMaterial:
	var key: String = "outline|%s|%s" % [width, occludable]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("occludable", occludable)
	_cache[key] = m
	return m


static func facade(wall: Color, seed_value: float, lit_ratio: float = 0.4, ground_floor_h: float = 3.0) -> ShaderMaterial:
	var key: String = "facade|%s|%s|%s|%s" % [wall.to_html(), seed_value, lit_ratio, ground_floor_h]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = WINDOWS
	m.set_shader_parameter("wall_color", wall)
	m.set_shader_parameter("seed", seed_value)
	m.set_shader_parameter("lit_ratio", lit_ratio)
	m.set_shader_parameter("ground_floor_h", ground_floor_h)
	m.next_pass = outline_mat(0.02, true)
	_cache[key] = m
	return m


static func asphalt(color: Color = Color("#2A2A32"), puddles: float = 0.3) -> ShaderMaterial:
	var key: String = "asphalt|%s|%s" % [color.to_html(), puddles]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = ASPHALT
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("puddle_amount", puddles)
	_cache[key] = m
	return m


static func neon(color: Color, energy: float = 3.0, flicker: float = 0.0, seed_value: float = 0.0) -> ShaderMaterial:
	var key: String = "neon|%s|%s|%s|%s" % [color.to_html(), energy, flicker, seed_value]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = NEON
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("flicker", flicker)
	m.set_shader_parameter("seed", seed_value)
	_cache[key] = m
	return m


static func clear_cache() -> void:
	_cache.clear()
