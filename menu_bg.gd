extends Control
# Animated menu backdrop: sky gradient, sun, drifting clouds, rolling hills,
# a dirt strip and a few worms inching along the grass.

var t := 0.0
var clouds: Array = []
var worms: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(8):
		clouds.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.06, 0.38),
			"s": rng.randf_range(0.7, 1.5),
			"v": rng.randf_range(0.004, 0.012),
		})
	for i in range(4):
		var dir := 1.0 if i % 2 == 0 else -1.0
		worms.append({
			"x": rng.randf(),
			"v": rng.randf_range(0.012, 0.022) * dir,
			"phase": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	t += delta
	for c in clouds:
		c["x"] = fposmod(c["x"] + c["v"] * delta, 1.3)
	for w in worms:
		w["x"] = fposmod(w["x"] + w["v"] * delta, 1.2)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# sky
	var top := Color(0.30, 0.56, 0.90)
	var bottom := Color(0.78, 0.90, 0.98)
	var bands := 36
	for i in range(bands):
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(0, h * float(i) / bands, w, h / bands + 1.0), top.lerp(bottom, f))

	# sun
	draw_circle(Vector2(w * 0.82, h * 0.2), 70.0, Color(1.0, 0.95, 0.7, 0.25))
	draw_circle(Vector2(w * 0.82, h * 0.2), 46.0, Color(1.0, 0.96, 0.75))

	# clouds
	for c in clouds:
		var cx: float = (c["x"] - 0.15) * w
		var cy: float = c["y"] * h
		var s: float = c["s"]
		var col := Color(1, 1, 1, 0.85)
		draw_circle(Vector2(cx, cy), 26.0 * s, col)
		draw_circle(Vector2(cx + 28.0 * s, cy + 6.0 * s), 20.0 * s, col)
		draw_circle(Vector2(cx - 28.0 * s, cy + 8.0 * s), 18.0 * s, col)
		draw_rect(Rect2(cx - 40.0 * s, cy + 8.0 * s, 80.0 * s, 18.0 * s), col)

	# hills (two layers)
	var ground_y := h * 0.80
	_hills(ground_y - 70.0, 38.0, 0.0, Color(0.42, 0.68, 0.48))
	_hills(ground_y - 30.0, 30.0, 2.0, Color(0.32, 0.60, 0.33))

	# grass + dirt strip
	draw_rect(Rect2(0, ground_y, w, 14.0), Color(0.30, 0.62, 0.26))
	draw_rect(Rect2(0, ground_y, w, 4.0), Color(0.42, 0.74, 0.34))
	var tile := 32.0
	var y := ground_y + 14.0
	var row := 0
	while y < h:
		var x := 0.0
		var col_i := 0
		while x < w:
			var shade := float((col_i * 73 + row * 151) % 9) / 9.0 * 0.08
			var base := Color(0.47, 0.31, 0.18) if row < 3 else Color(0.46, 0.47, 0.52)
			draw_rect(Rect2(x, y, tile, tile), base.lightened(shade))
			x += tile
			col_i += 1
		y += tile
		row += 1

	# worms on the grass
	for wm in worms:
		_draw_worm(wm, ground_y, w)


func _hills(base_y: float, amp: float, offset: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= size.x + 24.0:
		var y := base_y + sin(x * 0.0045 + offset) * amp + sin(x * 0.013 + offset * 2.0) * amp * 0.35
		pts.append(Vector2(x, y))
		x += 24.0
	pts.append(Vector2(size.x + 24.0, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)


func _draw_worm(wm: Dictionary, ground_y: float, w: float) -> void:
	var dir: float = 1.0 if wm["v"] > 0.0 else -1.0
	var hx: float = (wm["x"] - 0.1) * w
	var phase: float = wm["phase"]
	var segs := 7
	for i in range(segs - 1, -1, -1):
		var px := hx - dir * float(i) * 13.0
		var hump := absf(sin(t * 3.0 + phase - float(i) * 0.55)) * 9.0
		var py := ground_y - 6.0 - hump
		var r := lerpf(11.0, 7.0, float(i) / float(segs))
		var col := Color(0.95, 0.55, 0.60) if i == 0 else Color(0.85, 0.45, 0.50).darkened(0.03 * i)
		draw_circle(Vector2(px, py), r, col)
		if i == 0:
			var eye := Vector2(px + dir * 4.5, py - 3.0)
			draw_circle(eye, 3.2, Color.WHITE)
			draw_circle(eye + Vector2(dir * 1.2, 0), 1.6, Color.BLACK)
