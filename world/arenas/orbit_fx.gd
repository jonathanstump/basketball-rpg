class_name OrbitFx
extends Node3D
## Draws Atlas's orbit rings and the rolling globe (spec §9.3) from the
## gimmick's live hitboxes, so what you see is exactly what hits you.

var gimmick: AtlasGimmick
var _spokes: Array[MeshInstance3D] = []
var _globe: MeshInstance3D = null


func _process(_delta: float) -> void:
	if gimmick == null:
		return
	while _spokes.size() < gimmick.rings.size():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.material_override = ToonMaterials.neon(Color("#9FE8FF") if _spokes.size() != 1 else Color("#FFB000"), 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_spokes.append(mi)
	for i: int in _spokes.size():
		var on: bool = i < gimmick.rings.size()
		_spokes[i].visible = on
		if not on:
			continue
		var v: HitVolume = gimmick.rings[i].volume
		_spokes[i].mesh = MeshLib.box(Vector3(0.35, maxf(0.15, v.height * 0.5), v.length))
		_spokes[i].position = v.origin + v.fwd() * (v.length * 0.5) + Vector3(0, v.y_offset + v.height * 0.5, 0)
		_spokes[i].rotation.y = v.yaw
	if gimmick.globe != null:
		if _globe == null:
			_globe = MeshInstance3D.new()
			_globe.mesh = MeshLib.sphere(1.4)
			_globe.material_override = ToonMaterials.toon(Color("#C8D0DA"), true, false, Color("#9FE8FF"), 0.4)
			add_child(_globe)
		_globe.position = gimmick.globe.volume.origin + Vector3(0, 1.4, 0)
		_globe.rotation.x += 0.05
