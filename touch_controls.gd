extends Control
# On-screen touch controls: move pad (left/right), jump button, a Break/Place
# mode button, and a pause button. Any touch that is not on a button "aims":
# tap or hold the world to break or place the block under your finger.
# Also accepts a real mouse so you can test it on a computer
# (Settings -> Touch controls -> On).

signal pause_pressed

var active := false
var move_dir := 0.0
var jump_held := false
var place_mode := false
var aim_active := false
var aim_screen := Vector2.ZERO
var blocks_text := ""

var touches := {}      # touch index -> role ("move", "jump", "aim", ...)
var sb_up: StyleBoxFlat
var sb_down: StyleBoxFlat
var sb_place: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	sb_up = _style(Color(1, 1, 1, 0.16))
	sb_down = _style(Color(1, 1, 1, 0.38))
	sb_place = _style(Color(0.36, 0.78, 0.38, 0.55))


func _style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(22)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, 0.35)
	return s


func set_active(v: bool) -> void:
	active = v
	visible = v
	if not v:
		touches.clear()
		move_dir = 0.0
		jump_held = false
		aim_active = false


func _rects() -> Dictionary:
	var m := 24.0
	var s := 104.0
	var by := size.y - m - s
	return {
		"left": Rect2(m, by, s, s),
		"right": Rect2(m + s + 14.0, by, s, s),
		"jump": Rect2(size.x - m - 124.0, size.y - m - 124.0, 124.0, 124.0),
		"mode": Rect2(size.x - m - 150.0, size.y - m - 124.0 - 14.0 - 70.0, 150.0, 70.0),
		"pause": Rect2(size.x * 0.5 - 26.0, 10.0, 52.0, 52.0),
	}


func _role_at(pos: Vector2) -> String:
	var r := _rects()
	for key in ["pause", "jump", "mode"]:
		if (r[key] as Rect2).has_point(pos):
			return key
	var zone: Rect2 = (r["left"] as Rect2).merge(r["right"] as Rect2).grow(12.0)
	if zone.has_point(pos):
		return "move"
	return "aim"


func _move_from(pos: Vector2) -> void:
	var r := _rects()
	var mid := ((r["left"] as Rect2).end.x + (r["right"] as Rect2).position.x) * 0.5
	move_dir = -1.0 if pos.x < mid else 1.0


func _press(idx: int, pos: Vector2) -> void:
	var role := _role_at(pos)
	touches[idx] = role
	match role:
		"move":
			_move_from(pos)
		"jump":
			jump_held = true
		"mode":
			place_mode = not place_mode
		"pause":
			pause_pressed.emit()
		"aim":
			aim_active = true
			aim_screen = pos


func _drag(idx: int, pos: Vector2) -> void:
	if not touches.has(idx):
		return
	match touches[idx]:
		"move":
			_move_from(pos)
		"aim":
			aim_screen = pos


func _release(idx: int) -> void:
	if not touches.has(idx):
		return
	var role: String = touches[idx]
	touches.erase(idx)
	match role:
		"move":
			move_dir = 0.0
		"jump":
			jump_held = false
		"aim":
			aim_active = touches.values().has("aim")


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(99, event.position)
			else:
				_release(99)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag(99, event.position)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	var r := _rects()
	var font := ThemeDB.fallback_font
	var white := Color(1, 1, 1, 0.9)

	var lr: Rect2 = r["left"]
	var rr: Rect2 = r["right"]
	var jr: Rect2 = r["jump"]
	var mr: Rect2 = r["mode"]
	var pr: Rect2 = r["pause"]

	draw_style_box(sb_down if move_dir < 0.0 else sb_up, lr)
	draw_style_box(sb_down if move_dir > 0.0 else sb_up, rr)
	draw_style_box(sb_down if jump_held else sb_up, jr)
	draw_style_box(sb_place if place_mode else sb_up, mr)
	draw_style_box(sb_up, pr)

	# arrows
	var lc := lr.get_center()
	draw_colored_polygon(PackedVector2Array([lc + Vector2(-18, 0), lc + Vector2(12, -24), lc + Vector2(12, 24)]), white)
	var rc := rr.get_center()
	draw_colored_polygon(PackedVector2Array([rc + Vector2(18, 0), rc + Vector2(-12, -24), rc + Vector2(-12, 24)]), white)
	var jc := jr.get_center()
	draw_colored_polygon(PackedVector2Array([jc + Vector2(0, -26), jc + Vector2(-28, 16), jc + Vector2(28, 16)]), white)

	# pause bars
	var pc := pr.get_center()
	draw_rect(Rect2(pc + Vector2(-11, -13), Vector2(8, 26)), white)
	draw_rect(Rect2(pc + Vector2(3, -13), Vector2(8, 26)), white)

	# mode label
	var label := "PLACE  %s" % blocks_text if place_mode else "BREAK"
	draw_string(font, mr.position + Vector2(0, mr.size.y * 0.5 + 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 22, Color.WHITE)
