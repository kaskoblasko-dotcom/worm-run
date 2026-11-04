extends Control
# Main menu with separate screens:
#   connect -> auth (log in / sign up) -> main (play) -> join / how to play / settings
# Works with mouse, keyboard and touch. Settings are saved on this device.

const UITheme = preload("res://scripts/ui_theme.gd")
const BgScript = preload("res://scripts/menu_bg.gd")
const SETTINGS_PATH := "user://settings.cfg"
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

signal signup_requested(username: String, password: String)
signal login_requested(username: String, password: String)
signal logout_requested
signal create_room_requested
signal join_room_requested(code: String)
signal settings_changed

# ---- settings (saved on this device) ----
var touch_mode := 0      # 0 = auto, 1 = always on, 2 = off
var zoom_level := 1      # 0 = close, 1 = normal, 2 = far
var saved_username := ""

var player_name := ""
var current_screen := ""
var screens := {}

var status_label: Label
var welcome_label: Label
var user_edit: LineEdit
var pass_edit: LineEdit
var code_edit: LineEdit
var submit_btn: Button
var signup_hint: Label
var login_tab: Button
var signup_tab: Button


# A small spinning ring for the "connecting" screen.
class Spinner extends Control:
	var angle := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func _process(delta: float) -> void:
		angle += delta * 5.0
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 22.0, 0.0, TAU, 40, Color(1, 1, 1, 0.14), 6.0, true)
		draw_arc(c, 22.0, angle, angle + PI * 1.2, 28, Color(0.36, 0.78, 0.38), 6.0, true)


func _ready() -> void:
	theme = UITheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()

	add_child(BgScript.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)

	var title := _label("WORM RUN", "TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var tagline := _label("Run from the worms. Break blocks. Build walls.", "")
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	tagline.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.9))
	tagline.add_theme_constant_override("outline_size", 6)
	column.add_child(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(gap)

	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(480, 0)
	column.add_child(card)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 14)
	card.add_child(card_box)

	_build_connect(card_box)
	_build_auth(card_box)
	_build_main(card_box)
	_build_join(card_box)
	_build_help(card_box)
	_build_settings(card_box)

	status_label = _label("", "WarnLabel")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(420, 0)
	status_label.visible = false
	card_box.add_child(status_label)

	show_connecting("")


# =====================================================================
#  Small builders
# =====================================================================

func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l


func _button(text: String, variation: String = "", min_h: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	if variation != "":
		b.theme_type_variation = variation
	return b


func _make_screen(parent: Control, screen_name: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.visible = false
	parent.add_child(v)
	screens[screen_name] = v
	return v


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r


func _segmented(parent: Control, options: Array, current: int, on_pick: Callable) -> void:
	var row := _row(parent)
	var group := ButtonGroup.new()
	for i in range(options.size()):
		var b := _button(options[i], "SegButton", 52)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (i == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): on_pick.call(i))
		row.add_child(b)


# =====================================================================
#  Screens
# =====================================================================

func _build_connect(parent: Control) -> void:
	var s := _make_screen(parent, "connect")
	var h := _label("Connecting to server", "HeadingLabel")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(h)
	s.add_child(Spinner.new())
	var d := _label("A free server falls asleep when idle, so the first connection can take up to a minute. The game keeps retrying by itself.", "DimLabel")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(420, 0)
	s.add_child(d)


func _build_auth(parent: Control) -> void:
	var s := _make_screen(parent, "auth")

	var tabs := _row(s)
	var group := ButtonGroup.new()
	login_tab = _button("Log in", "SegButton", 50)
	signup_tab = _button("Sign up", "SegButton", 50)
	for b in [login_tab, signup_tab]:
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	login_tab.button_pressed = true
	group.pressed.connect(func(_b): _update_auth_mode())

	user_edit = LineEdit.new()
	user_edit.placeholder_text = "Username"
	user_edit.max_length = 16
	user_edit.text = saved_username
	user_edit.text_submitted.connect(func(_t): pass_edit.grab_focus())
	s.add_child(user_edit)

	pass_edit = LineEdit.new()
	pass_edit.placeholder_text = "Password"
	pass_edit.max_length = 64
	pass_edit.secret = true
	pass_edit.text_submitted.connect(func(_t): _submit_auth())
	s.add_child(pass_edit)

	var show_pw := CheckBox.new()
	show_pw.text = "Show password"
	show_pw.toggled.connect(func(on: bool): pass_edit.secret = not on)
	s.add_child(show_pw)

	signup_hint = _label("Username: 3-16 letters, numbers or _\nPassword: at least 4 characters", "DimLabel")
	signup_hint.visible = false
	s.add_child(signup_hint)

	submit_btn = _button("Log in", "PrimaryButton", 60)
	submit_btn.pressed.connect(_submit_auth)
	s.add_child(submit_btn)


func _build_main(parent: Control) -> void:
	var s := _make_screen(parent, "main")

	welcome_label = _label("Welcome!", "HeadingLabel")
	welcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(welcome_label)

	var create_btn := _button("Create room", "PrimaryButton", 68)
	create_btn.pressed.connect(func(): create_room_requested.emit())
	s.add_child(create_btn)

	var join_btn := _button("Join room", "", 60)
	join_btn.pressed.connect(func(): _show_screen("join"))
	s.add_child(join_btn)

	var row := _row(s)
	var help_btn := _button("How to play", "", 52)
	help_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_btn.pressed.connect(func(): _show_screen("help"))
	row.add_child(help_btn)
	var set_btn := _button("Settings", "", 52)
	set_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_btn.pressed.connect(func(): _show_screen("settings"))
	row.add_child(set_btn)

	var out_btn := _button("Log out", "GhostButton", 46)
	out_btn.pressed.connect(func(): logout_requested.emit())
	s.add_child(out_btn)


func _build_join(parent: Control) -> void:
	var s := _make_screen(parent, "join")
	var h := _label("Join a room", "HeadingLabel")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(h)

	var d := _label("Ask your friend for their 4-letter room code.", "DimLabel")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(d)

	code_edit = LineEdit.new()
	code_edit.placeholder_text = "K7QD"
	code_edit.max_length = 6
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_size_override("font_size", 44)
	code_edit.custom_minimum_size = Vector2(0, 78)
	code_edit.text_changed.connect(_filter_code)
	code_edit.text_submitted.connect(func(_t): _submit_code())
	s.add_child(code_edit)

	var go := _button("Join", "PrimaryButton", 62)
	go.pressed.connect(_submit_code)
	s.add_child(go)

	var row := _row(s)
	var paste := _button("Paste code", "", 50)
	paste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste.pressed.connect(func():
		code_edit.text = ""
		code_edit.text = _clean_code(DisplayServer.clipboard_get())
		code_edit.caret_column = code_edit.text.length())
	row.add_child(paste)
	var back := _button("Back", "GhostButton", 50)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): _show_screen("main"))
	row.add_child(back)


func _build_help(parent: Control) -> void:
	var s := _make_screen(parent, "help")
	var h := _label("How to play", "HeadingLabel")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(h)

	var goal := _label("Worms hunt you across the map. Survive as long as you can, dig down, and build walls to block them. Your longest survival goes on the leaderboard.", "")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(420, 0)
	s.add_child(goal)

	var kb_head := _label("Keyboard and mouse", "DimLabel")
	s.add_child(kb_head)
	var kb := _label("A / D or arrows: move\nW / Space: jump\nLeft click: break a block\nRight click: place a block\nEsc: pause menu", "")
	s.add_child(kb)

	var t_head := _label("Touch", "DimLabel")
	s.add_child(t_head)
	var tc := _label("Left pad: move    Right button: jump\nTap or hold the world: break / place\nBreak/Place button: switch what a tap does", "")
	tc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tc.custom_minimum_size = Vector2(420, 0)
	s.add_child(tc)

	var back := _button("Back", "", 54)
	back.pressed.connect(func(): _show_screen("main"))
	s.add_child(back)


func _build_settings(parent: Control) -> void:
	var s := _make_screen(parent, "settings")
	var h := _label("Settings", "HeadingLabel")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(h)

	s.add_child(_label("Touch controls", "DimLabel"))
	_segmented(s, ["Auto", "On", "Off"], touch_mode, func(i: int):
		touch_mode = i
		_save_settings()
		settings_changed.emit())
	var hint := _label("Auto turns them on for phones and tablets.", "DimLabel")
	s.add_child(hint)

	s.add_child(_label("Camera zoom", "DimLabel"))
	_segmented(s, ["Close", "Normal", "Far"], zoom_level, func(i: int):
		zoom_level = i
		_save_settings()
		settings_changed.emit())

	var back := _button("Back", "", 54)
	back.pressed.connect(func(): _show_screen("main"))
	s.add_child(back)


# =====================================================================
#  Behaviour
# =====================================================================

func _show_screen(screen_name: String) -> void:
	current_screen = screen_name
	for k in screens:
		screens[k].visible = (k == screen_name)
	var s: Control = screens[screen_name]
	s.modulate.a = 0.0
	create_tween().tween_property(s, "modulate:a", 1.0, 0.18)
	if screen_name != "connect":
		set_status("")


func _update_auth_mode() -> void:
	var signup := signup_tab.button_pressed
	submit_btn.text = "Create account" if signup else "Log in"
	signup_hint.visible = signup
	set_status("")


func _submit_auth() -> void:
	var u := user_edit.text.strip_edges()
	saved_username = u
	_save_settings()
	if signup_tab.button_pressed:
		signup_requested.emit(u, pass_edit.text)
	else:
		login_requested.emit(u, pass_edit.text)


func _clean_code(t: String) -> String:
	var out := ""
	for ch in t.to_upper():
		if CODE_LETTERS.contains(ch):
			out += ch
	return out.substr(0, 6)


func _filter_code(t: String) -> void:
	var cleaned := _clean_code(t)
	if cleaned != t:
		var pos := code_edit.caret_column
		code_edit.text = cleaned
		code_edit.caret_column = mini(pos, cleaned.length())


func _submit_code() -> void:
	if code_edit.text.length() < 4:
		set_status("Room codes have 4 letters or numbers.")
		return
	join_room_requested.emit(code_edit.text)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and current_screen in ["join", "help", "settings"]:
		_show_screen("main")
		get_viewport().set_input_as_handled()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	touch_mode = clampi(int(cfg.get_value("input", "touch_mode", 0)), 0, 2)
	zoom_level = clampi(int(cfg.get_value("view", "zoom", 1)), 0, 2)
	saved_username = str(cfg.get_value("account", "username", ""))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "touch_mode", touch_mode)
	cfg.set_value("view", "zoom", zoom_level)
	cfg.set_value("account", "username", saved_username)
	cfg.save(SETTINGS_PATH)


# =====================================================================
#  API used by main.gd
# =====================================================================

func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = text != ""


func set_player(player: String) -> void:
	player_name = player
	welcome_label.text = "Welcome, %s!" % player


func show_connecting(text: String) -> void:
	_show_screen("connect")
	set_status(text)


func show_login(text: String) -> void:
	_show_screen("auth")
	set_status(text)
	pass_edit.text = ""
	if user_edit.text == "":
		user_edit.grab_focus()
	else:
		pass_edit.grab_focus()


func show_rooms(text: String) -> void:
	_show_screen("main")
	set_status(text)
