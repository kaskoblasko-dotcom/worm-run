extends Node2D
# The tile world: stores blocks, generates terrain, draws itself, and
# does box-vs-tile collision for players and worms.

const TILE := 16
const W := 192
const H := 80

const AIR := 0
const DIRT := 1
const STONE := 2
const GRASS := 3
const WOOD := 4
const BEDROCK := 5

var tiles: PackedByteArray = PackedByteArray()


func _init() -> void:
	tiles.resize(W * H)


func generate(seed_value: int) -> void:
	var terrain := FastNoiseLite.new()
	terrain.seed = seed_value
	terrain.frequency = 0.02
	var caves := FastNoiseLite.new()
	caves.seed = seed_value + 7
	caves.frequency = 0.06
	for x in range(W):
		var surface := 26 + int(terrain.get_noise_1d(x) * 9.0)
		for y in range(H):
			var t := AIR
			if y == H - 1:
				t = BEDROCK
			elif y == surface:
				t = GRASS
			elif y > surface:
				if y > surface + 10:
					t = STONE
				else:
					t = DIRT
				if y > surface + 4 and y < H - 2 and caves.get_noise_2d(x, y) > 0.35:
					t = AIR
			tiles[y * W + x] = t
	queue_redraw()


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H


func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= W or y >= H:
		return BEDROCK
	if y < 0:
		return AIR
	return tiles[y * W + x]


func set_tile(x: int, y: int, t: int) -> void:
	if not in_bounds(x, y):
		return
	tiles[y * W + x] = t
	queue_redraw()


func is_solid(x: int, y: int) -> bool:
	return get_tile(x, y) != AIR


func surface_y(x: int) -> int:
	x = clampi(x, 0, W - 1)
	for y in range(H):
		if tiles[y * W + x] != AIR:
			return y
	return H - 1


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


# Does a box (center + half size) overlap any solid tile?
func box_hits(center: Vector2, hs: Vector2) -> bool:
	var x0 := floori((center.x - hs.x) / TILE)
	var x1 := floori((center.x + hs.x - 0.001) / TILE)
	var y0 := floori((center.y - hs.y) / TILE)
	var y1 := floori((center.y + hs.y - 0.001) / TILE)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if is_solid(tx, ty):
				return true
	return false


# Moves a box, sliding along tiles. Returns pos, vel, floor, wall, ceiling.
func move_box(pos: Vector2, vel: Vector2, hs: Vector2, dt: float) -> Dictionary:
	var on_floor := false
	var wall := false
	var ceiling := false

	var nx := pos.x + vel.x * dt
	if box_hits(Vector2(nx, pos.y), hs):
		if vel.x > 0.0:
			nx = floorf((nx + hs.x) / TILE) * TILE - hs.x - 0.01
		elif vel.x < 0.0:
			nx = (floorf((nx - hs.x) / TILE) + 1.0) * TILE + hs.x + 0.01
		else:
			nx = pos.x
		vel.x = 0.0
		wall = true

	var ny := pos.y + vel.y * dt
	if box_hits(Vector2(nx, ny), hs):
		if vel.y > 0.0:
			ny = floorf((ny + hs.y) / TILE) * TILE - hs.y - 0.01
			on_floor = true
		elif vel.y < 0.0:
			ny = (floorf((ny - hs.y) / TILE) + 1.0) * TILE + hs.y + 0.01
			ceiling = true
		else:
			ny = pos.y
		vel.y = 0.0

	return {
		"pos": Vector2(nx, ny),
		"vel": vel,
		"floor": on_floor,
		"wall": wall,
		"ceiling": ceiling,
	}


func _tile_color(t: int, x: int, y: int) -> Color:
	var shade := float((x * 73 + y * 151) % 9) / 9.0 * 0.08
	match t:
		DIRT:
			return Color(0.47, 0.31, 0.18).lightened(shade)
		STONE:
			return Color(0.46, 0.47, 0.52).lightened(shade)
		GRASS:
			return Color(0.30, 0.60, 0.25).lightened(shade)
		WOOD:
			return Color(0.74, 0.54, 0.28).lightened(shade)
		BEDROCK:
			return Color(0.14, 0.14, 0.17)
	return Color.MAGENTA


func _draw() -> void:
	for y in range(H):
		for x in range(W):
			var t := tiles[y * W + x]
			if t == AIR:
				continue
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), _tile_color(t, x, y))
