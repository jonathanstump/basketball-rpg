extends Control
## Entry scene. M0: shows the logo card and confirms data is loaded.
## TODO(spec §3.3): replaced by the title screen flow in M8.


func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0A0A14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var label: Label = Label.new()
	label.text = tr("CONCRETE CROWN") + "\n" + tr("One ball. Five boroughs. No fouls.")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 48)
	add_child(label)
