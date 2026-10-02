class_name MenuHost
extends Node
## Minimal menu host for tests (same open_menu/close_menu contract as the
## title screen and GameWorld): one menu at a time, `current` is the open one.

var current: CanvasLayer = null


func open_menu(m: CanvasLayer) -> void:
	close_menu()
	current = m
	add_child(m)


func close_menu() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null
