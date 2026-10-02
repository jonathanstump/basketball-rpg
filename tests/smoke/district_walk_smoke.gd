extends Node
## Smoke: district_walk (spec §16 M6) — the QA bot walks Bed-Stuy, opens a
## shoebox, taps into the station, enters a bodega, rests with the cat and
## fast-travels by subway. A persistent driver survives scene changes.


func _ready() -> void:
	var driver: Node = (load("res://tests/smoke/district_walk_driver.gd") as GDScript).new()
	driver.name = "DistrictWalkDriver"
	get_tree().root.call_deferred("add_child", driver)
