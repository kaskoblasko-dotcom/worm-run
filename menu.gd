extends Control
# Title screen. Three stages:
#   connecting -> sign up / log in -> create a room or type a room code

signal signup_requested(username: String, password: String)
signal login_requested(username: String, password: String)
signal create_room_requested
signal join_room_requested(code: String)

var login_box: VBoxContainer
var rooms_box: VBoxContainer
var status_label: Label
var user_edit: LineEdit
var pass_edit: LineEdit
var code_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.11, 0.16)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "WORM RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Run from the worms. Break blocks. Build walls."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	# ---- Stage 2: account ----
	login_box = VBoxContainer.new()
	login_box.add_theme_constant_override("separation", 8)
	root.add_child(login_box)

	user_edit = LineEdit.new()
	user_edit.placeholder_text = "Username (3-16 letters, numbers, _)"
	login_box.add_child(user_edit)

	pass_edit = LineEdit.new()
	pass_edit.placeholder_text = "Password (4+ characters)"
	pass_edit.secret = true
	pass_edit.text_submitted.connect(func(_t): login_requested.emit(user_edit.text, pass_edit.text))
	login_box.add_child(pass_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	login_box.add_child(row)

	var signup_btn := Button.new()
	signup_btn.text = "Sign up"
	signup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signup_btn.pressed.connect(func(): signup_requested.emit(user_edit.text, pass_edit.text))
	row.add_child(signup_btn)

	var login_btn := Button.new()
	login_btn.text = "Log in"
	login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_btn.pressed.connect(func(): login_requested.emit(user_edit.text, pass_edit.text))
	row.add_child(login_btn)

	# ---- Stage 3: rooms ----
	rooms_box = VBoxContainer.new()
	rooms_box.add_theme_constant_override("separation", 8)
	root.add_child(rooms_box)

	var create_btn := Button.new()
	create_btn.text = "Create a room"
	create_btn.pressed.connect(func(): create_room_requested.emit())
	rooms_box.add_child(create_btn)

	var or_label := Label.new()
	or_label.text = "or join your friend's room:"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rooms_box.add_child(or_label)

	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Room code (like K7QD)"
	code_edit.max_length = 6
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.text_submitted.connect(func(_t): join_room_requested.emit(code_edit.text))
	rooms_box.add_child(code_edit)

	var join_btn := Button.new()
	join_btn.text = "Join room"
	join_btn.pressed.connect(func(): join_room_requested.emit(code_edit.text))
	rooms_box.add_child(join_btn)

	# ---- Status + controls ----
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	root.add_child(status_label)

	var help := Label.new()
	help.text = "A/D or arrows: move   W/Space: jump\nLeft click: break   Right click: place   Esc: leave room"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	root.add_child(help)

	show_connecting("")


func set_status(text: String) -> void:
	status_label.text = text


func show_connecting(text: String) -> void:
	login_box.visible = false
	rooms_box.visible = false
	set_status(text)


func show_login(text: String) -> void:
	login_box.visible = true
	rooms_box.visible = false
	set_status(text)
	user_edit.grab_focus()


func show_rooms(text: String) -> void:
	login_box.visible = false
	rooms_box.visible = true
	set_status(text)
	code_edit.grab_focus()
