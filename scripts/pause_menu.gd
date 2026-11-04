extends Control
# In-game pause menu (Esc on keyboard, pause button on touch, Back on Android).
# The online world keeps running while this is open.

const UITheme = preload("res://scripts/ui_theme.gd")

signal resume_requested
signal leave_requested
signal copy_requested

var code_label: Label


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(400, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.theme_type_variation = "HeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var dim_label := Label.new()
	dim_label.text = "ROOM CODE"
	dim_label.theme_type_variation = "DimLabel"
	dim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dim_label)

	code_label = Label.new()
	code_label.add_theme_font_size_override("font_size", 52)
	code_label.add_theme_color_override("font_color", UITheme.ACCENT)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(code_label)

	var note := Label.new()
	note.text = "The world keeps running while you are here."
	note.theme_type_variation = "DimLabel"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	var resume := Button.new()
	resume.text = "Resume"
	resume.theme_type_variation = "PrimaryButton"
	resume.custom_minimum_size = Vector2(0, 62)
	resume.pressed.connect(func(): resume_requested.emit())
	box.add_child(resume)

	var copy := Button.new()
	copy.text = "Copy room code"
	copy.custom_minimum_size = Vector2(0, 54)
	copy.pressed.connect(func(): copy_requested.emit())
	box.add_child(copy)

	var leave := Button.new()
	leave.text = "Leave room"
	leave.theme_type_variation = "DangerButton"
	leave.custom_minimum_size = Vector2(0, 54)
	leave.pressed.connect(func(): leave_requested.emit())
	box.add_child(leave)


func open(code: String) -> void:
	code_label.text = code
	visible = true


func close() -> void:
	visible = false
