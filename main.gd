extends Node2D
# Worm Run - one script for the game CLIENT and the dedicated SERVER.
#
#   Client: just run the project. It connects to SERVER_URL by itself.
#   Server: godot --headless --path . -- --server     (Render runs this for you)
#
# The server keeps accounts and many rooms. Each room has its own world,
# worms and players. Players join a room with a 4-letter code.

const WorldScript = preload("res://scripts/world.gd")
const MenuScript = preload("res://scripts/menu.gd")
const UITheme = preload("res://scripts/ui_theme.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const PauseScript = preload("res://scripts/pause_menu.gd")

# >>> After you deploy to Render, put your server address here <<<
# (for testing on your own computer use "ws://127.0.0.1:10000")
const SERVER_URL := "wss://YOUR-APP-NAME.onrender.com"

const DEFAULT_PORT := 10000
const MAX_ROOMS := 20
const MAX_PER_ROOM := 8
const ACCOUNTS_PATH := "user://accounts.json"

const T := 16
const PLAYER_HS := Vector2(6, 7)
const WORM_HS := Vector2(8, 5)
const GRAVITY := 900.0
const MAX_FALL := 450.0
const PLAYER_SPEED := 150.0
const PLAYER_JUMP := 300.0
const REACH := 80.0
const START_BLOCKS := 20
const MAX_BLOCKS := 999

const WORM_SPEED_CHASE := 72.0
const WORM_SPEED_WANDER := 30.0
const WORM_SIGHT := 420.0
const WORM_JUMP := 230.0
const WORM_CLIMB := 55.0
const WORM_DIG_TIME := 1.2


class PlayerData:
	var uname := ""
	var pos := Vector2.ZERO
	var facing := 1
	var blocks := 0
	var alive := 0.0
	var best := 0.0
	var deaths := 0
	var invuln := 0.0


class WormData:
	var id := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var facing := 1
	var on_floor := false
	var hit_wall := false
	var hit_ceiling := false
	var dig_t := 0.0
	var digging := false
	var wander_dir := 0
	var wander_t := 0.0


class RoomData:
	var code := ""
	var world = null          # a world.gd instance (not in the scene tree)
	var peers := {}           # peer id -> PlayerData
	var worms := {}           # worm id -> WormData
	var next_worm_id := 1
	var snap_timer := 0.0
	var spawn_timer := 0.0


# ---- scene nodes ----
var world: WorldScript
var menu: MenuScript
var camera: Camera2D
var ui: CanvasLayer
var hud_label: Label
var board_label: Label
var help_label: Label
var toast_label: Label
var hud_panel: PanelContainer
var board_panel: PanelContainer
var toast_panel: PanelContainer
var ui_theme: Theme
var touch: Control
var pause_menu: Control
var rotate_overlay: ColorRect

# ---- client state ----
var in_game := false
var paused := false
var use_touch_ui := false
var aim_world := Vector2.ZERO
var connected := false
var connecting := false
var retrying := false
var retry_t := 0.0
var connect_time := 0.0
var attempts := 0
var ping_t := 0.0
var room_code := ""
var my_name := ""
var my_pos := Vector2.ZERO
var my_vel := Vector2.ZERO
var my_facing := 1
var my_blocks := 0
var my_invuln := false
var action_cd := 0.0
var send_timer := 0.0
var toast_time := 0.0
var players_view := {}   # peer id -> Dictionary
var worms_view := {}     # worm id -> Dictionary

# ---- server state ----
var is_server := false
var accounts := {}       # lowercase username -> {name, salt, hash}
var authed := {}         # peer id -> display name (logged in, maybe not in a room)
var player_room := {}    # peer id -> room code
var rooms := {}          # room code -> RoomData
var auth_attempts := {}


# =====================================================================
#  Setup
# =====================================================================

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.53, 0.78, 0.95))

	world = WorldScript.new()
	world.z_index = -1
	add_child(world)

	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)

	ui_theme = UITheme.build()
	ui = CanvasLayer.new()
	add_child(ui)
	_build_hud()

	touch = TouchScript.new()
	ui.add_child(touch)
	touch.pause_pressed.connect(func(): _set_paused(true))

	pause_menu = PauseScript.new()
	pause_menu.visible = false
	ui.add_child(pause_menu)
	pause_menu.resume_requested.connect(func(): _set_paused(false))
	pause_menu.leave_requested.connect(_leave_to_rooms)
	pause_menu.copy_requested.connect(_on_copy_code)

	menu = MenuScript.new()
	ui.add_child(menu)
	menu.signup_requested.connect(_on_signup_requested)
	menu.login_requested.connect(_on_login_requested)
	menu.logout_requested.connect(_on_logout_requested)
	menu.create_room_requested.connect(_on_create_room_requested)
	menu.join_room_requested.connect(_on_join_room_requested)
	menu.settings_changed.connect(_apply_settings)

	rotate_overlay = ColorRect.new()
	rotate_overlay.color = Color(0.04, 0.06, 0.10, 0.97)
	rotate_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_overlay.visible = false
	ui.add_child(rotate_overlay)
	var rotate_label := Label.new()
	rotate_label.text = "Please rotate your device\nto landscape"
	rotate_label.theme = ui_theme
	rotate_label.add_theme_font_size_override("font_size", 36)
	rotate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_overlay.add_child(rotate_label)

	_apply_settings()

	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if "--server" in OS.get_cmdline_user_args():
		menu.visible = false
		_start_server()
	else:
		_connect_to_server()


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.visible = false
	ui.add_child(l)
	return l


func _hud_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = ui_theme
	p.theme_type_variation = "HudPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	ui.add_child(p)
	return p


func _hud_text(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_hud() -> void:
	hud_panel = _hud_panel()
	hud_panel.position = Vector2(12, 8)
	hud_label = _hud_text(hud_panel, 18)

	board_panel = _hud_panel()
	board_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	board_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	board_panel.offset_left = -12.0
	board_panel.offset_right = -12.0
	board_panel.offset_top = 8.0
	board_panel.custom_minimum_size = Vector2(190, 0)
	board_label = _hud_text(board_panel, 16)
	board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	toast_panel = _hud_panel()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.offset_top = 72.0
	toast_label = _hud_text(toast_panel, 22)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	help_label = _make_label(14)
	help_label.anchor_top = 1.0
	help_label.anchor_bottom = 1.0
	help_label.offset_top = -30.0
	help_label.offset_bottom = -6.0
	help_label.offset_left = 12.0
	help_label.offset_right = 900.0
	help_label.text = "A/D move  |  W/Space jump  |  Left click: break  |  Right click: place  |  Esc: menu"


func _set_hud_visible(v: bool) -> void:
	hud_panel.visible = v
	board_panel.visible = v
	help_label.visible = v and not use_touch_ui
	if not v:
		toast_panel.visible = false


func _toast(text: String) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_time = 3.0


func _detect_touch() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(navigator.maxTouchPoints || 0) > 0 && window.matchMedia('(pointer: coarse)').matches"))
	return false


func _apply_settings() -> void:
	var zooms: Array = [2.5, 2.0, 1.5]
	var z: float = zooms[menu.zoom_level]
	camera.zoom = Vector2(z, z)
	match menu.touch_mode:
		1:
			use_touch_ui = true
		2:
			use_touch_ui = false
		_:
			use_touch_ui = _detect_touch()
	help_label.visible = in_game and not use_touch_ui
	_refresh_touch()


func _refresh_touch() -> void:
	touch.set_active(use_touch_ui and in_game and not paused)


func _set_paused(v: bool) -> void:
	paused = v and in_game
	if paused:
		pause_menu.open(room_code)
	else:
		pause_menu.close()
	_refresh_touch()


func _on_copy_code() -> void:
	DisplayServer.clipboard_set(room_code)
	_toast("Room code %s copied!" % room_code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and in_game:
		_set_paused(not paused)


# =====================================================================
#  Client: connecting (retries by itself, free servers sleep when idle)
# =====================================================================

func _connect_to_server() -> void:
	attempts += 1
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(SERVER_URL)
	if err != OK:
		attempts = 999
		menu.show_connecting("The server address (SERVER_URL in scripts/main.gd) is not valid.")
		return
	multiplayer.multiplayer_peer = peer
	connecting = true
	connect_time = 0.0
	menu.show_connecting("Connecting... a free server can take up to a minute to wake up. (try %d)" % attempts)


func _schedule_retry(message: String) -> void:
	connecting = false
	connected = false
	multiplayer.multiplayer_peer = null
	if attempts >= 40:
		menu.show_connecting("Could not reach the server. Check SERVER_URL in scripts/main.gd, then restart the game.")
		return
	retrying = true
	retry_t = 4.0
	menu.show_connecting(message)


func _on_connected() -> void:
	connecting = false
	connected = true
	attempts = 0
	ping_t = 0.0
	menu.show_login("Connected. Sign up or log in.")


func _on_connection_failed() -> void:
	_schedule_retry("Waiting for the server to wake up...")


func _on_server_disconnected() -> void:
	in_game = false
	paused = false
	pause_menu.close()
	_refresh_touch()
	players_view.clear()
	worms_view.clear()
	_set_hud_visible(false)
	menu.visible = true
	attempts = 0
	queue_redraw()
	_schedule_retry("Lost connection to the server.")


func _client_connection_tick(delta: float) -> void:
	if retrying:
		retry_t -= delta
		if retry_t <= 0.0:
			retrying = false
			_connect_to_server()
	elif connecting:
		connect_time += delta
		if connect_time > 25.0:
			_schedule_retry("Still waiting for the server...")
	elif connected:
		ping_t += delta
		if ping_t >= 20.0:
			ping_t = 0.0
			rpc_ping.rpc_id(1)


func _unhandled_input(event: InputEvent) -> void:
	if in_game and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_paused(not paused)


func _leave_to_rooms() -> void:
	rpc_leave_room.rpc_id(1)
	in_game = false
	paused = false
	pause_menu.close()
	_refresh_touch()
	players_view.clear()
	worms_view.clear()
	_set_hud_visible(false)
	menu.visible = true
	menu.show_rooms("You left room %s." % room_code)
	queue_redraw()


# =====================================================================
#  Client -> server menu requests
# =====================================================================

func _on_signup_requested(username: String, password: String) -> void:
	menu.set_status("Signing up...")
	rpc_auth.rpc_id(1, "signup", username, password)


func _on_login_requested(username: String, password: String) -> void:
	menu.set_status("Logging in...")
	rpc_auth.rpc_id(1, "login", username, password)


func _on_logout_requested() -> void:
	rpc_logout.rpc_id(1)
	my_name = ""
	menu.show_login("You have been logged out.")


func _on_create_room_requested() -> void:
	menu.set_status("Creating room...")
	rpc_create_room.rpc_id(1)


func _on_join_room_requested(code: String) -> void:
	menu.set_status("Joining...")
	rpc_join_room.rpc_id(1, code)


# =====================================================================
#  Server: start, accounts, rooms
# =====================================================================

func _start_server() -> void:
	var port := int(OS.get_environment("PORT"))
	if port <= 0:
		port = DEFAULT_PORT
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		printerr("Could not start server: %s" % error_string(err))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	_load_accounts()
	print("Worm Run server listening on port %d" % port)


func _on_peer_disconnected(id: int) -> void:
	if not is_server:
		return
	_leave_room(id)
	authed.erase(id)
	auth_attempts.erase(id)


func _validate_credentials(uname: String, password: String) -> String:
	if uname.length() < 3 or uname.length() > 16:
		return "Username must be 3-16 characters."
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_]+$")
	if re.search(uname) == null:
		return "Username can only use letters, numbers and _"
	if password.length() < 4 or password.length() > 64:
		return "Password must be 4-64 characters."
	return ""


func _hash_password(salt: String, password: String) -> String:
	var h := salt + password
	for i in range(2000):
		h = (h + salt).sha256_text()
	return h


func _load_accounts() -> void:
	accounts = {}
	if FileAccess.file_exists(ACCOUNTS_PATH):
		var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				accounts = data


func _save_accounts() -> void:
	var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(accounts))


func _new_code() -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	while code == "" or rooms.has(code):
		code = ""
		for i in range(4):
			code += letters[randi() % letters.length()]
	return code


func _room_of(id: int) -> RoomData:
	if not player_room.has(id):
		return null
	if not rooms.has(player_room[id]):
		return null
	return rooms[player_room[id]]


func _enter_room(id: int, room: RoomData) -> void:
	var p := PlayerData.new()
	p.uname = str(authed[id])
	p.blocks = START_BLOCKS
	p.invuln = 3.0
	p.pos = _spawn_point(room)
	room.peers[id] = p
	player_room[id] = room.code
	rpc_enter_room.rpc_id(id, room.code, p.uname, room.world.tiles, p.pos, p.blocks)


func _leave_room(id: int) -> void:
	var room := _room_of(id)
	player_room.erase(id)
	if room == null:
		return
	room.peers.erase(id)
	if room.peers.is_empty():
		room.world.free()
		rooms.erase(room.code)


# =====================================================================
#  RPCs: client -> server
# =====================================================================

@rpc("any_peer", "unreliable")
func rpc_ping() -> void:
	pass


@rpc("any_peer", "reliable")
func rpc_auth(mode: String, uname: String, password: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if authed.has(id):
		return

	auth_attempts[id] = int(auth_attempts.get(id, 0)) + 1
	if auth_attempts[id] > 10:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return

	uname = uname.strip_edges()
	var problem := _validate_credentials(uname, password)
	if problem != "":
		rpc_notice.rpc_id(id, problem)
		return

	var key := uname.to_lower()
	if mode == "signup":
		if accounts.has(key):
			rpc_notice.rpc_id(id, "That username is already taken.")
			return
		var salt := Crypto.new().generate_random_bytes(16).hex_encode()
		accounts[key] = {"name": uname, "salt": salt, "hash": _hash_password(salt, password)}
		_save_accounts()
	else:
		if not accounts.has(key):
			rpc_notice.rpc_id(id, "Wrong username or password.")
			return
		var acc: Dictionary = accounts[key]
		if _hash_password(acc["salt"], password) != acc["hash"]:
			rpc_notice.rpc_id(id, "Wrong username or password.")
			return

	var display := str(accounts[key]["name"])
	for pid in authed:
		if str(authed[pid]).to_lower() == key:
			rpc_notice.rpc_id(id, "That account is already logged in.")
			return

	authed[id] = display
	auth_attempts.erase(id)
	rpc_auth_ok.rpc_id(id, display)


@rpc("any_peer", "reliable")
func rpc_logout() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	_leave_room(id)
	authed.erase(id)
	auth_attempts.erase(id)


@rpc("any_peer", "reliable")
func rpc_create_room() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not authed.has(id) or player_room.has(id):
		return
	if rooms.size() >= MAX_ROOMS:
		rpc_notice.rpc_id(id, "The server is full right now. Try again in a bit.")
		return
	var room := RoomData.new()
	room.code = _new_code()
	room.world = WorldScript.new()
	room.world.generate(randi())
	rooms[room.code] = room
	_enter_room(id, room)


@rpc("any_peer", "reliable")
func rpc_join_room(code: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not authed.has(id) or player_room.has(id):
		return
	code = code.strip_edges().to_upper()
	if not rooms.has(code):
		rpc_notice.rpc_id(id, "No room with code \"%s\"." % code)
		return
	var room: RoomData = rooms[code]
	if room.peers.size() >= MAX_PER_ROOM:
		rpc_notice.rpc_id(id, "That room is full.")
		return
	_enter_room(id, room)


@rpc("any_peer", "reliable")
func rpc_leave_room() -> void:
	if not is_server:
		return
	_leave_room(multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable")
func rpc_state(pos: Vector2, facing: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var room := _room_of(id)
	if room == null:
		return
	var p: PlayerData = room.peers[id]
	p.pos = pos
	p.facing = facing


@rpc("any_peer", "reliable")
func rpc_break(tx: int, ty: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var room := _room_of(id)
	if room == null:
		return
	var p: PlayerData = room.peers[id]
	if not room.world.in_bounds(tx, ty) or not _in_reach(p.pos, tx, ty):
		return
	var t: int = room.world.get_tile(tx, ty)
	if t == WorldScript.AIR or t == WorldScript.BEDROCK:
		return
	_server_set_tile(room, tx, ty, WorldScript.AIR)
	p.blocks = mini(p.blocks + 1, MAX_BLOCKS)
	rpc_blocks.rpc_id(id, p.blocks)


@rpc("any_peer", "reliable")
func rpc_place(tx: int, ty: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var room := _room_of(id)
	if room == null:
		return
	var p: PlayerData = room.peers[id]
	if not room.world.in_bounds(tx, ty) or not _in_reach(p.pos, tx, ty):
		return
	if p.blocks <= 0 or room.world.get_tile(tx, ty) != WorldScript.AIR:
		return
	# don't entomb anyone
	for pid in room.peers:
		var other: PlayerData = room.peers[pid]
		if _tile_overlaps_box(tx, ty, other.pos, PLAYER_HS):
			return
	for wid in room.worms:
		var w: WormData = room.worms[wid]
		if _tile_overlaps_box(tx, ty, w.pos, WORM_HS):
			return
	_server_set_tile(room, tx, ty, WorldScript.WOOD)
	p.blocks -= 1
	rpc_blocks.rpc_id(id, p.blocks)


func _in_reach(from: Vector2, tx: int, ty: int) -> bool:
	var c := Vector2(tx * T + T * 0.5, ty * T + T * 0.5)
	return from.distance_to(c) <= REACH + 12.0


func _tile_overlaps_box(tx: int, ty: int, center: Vector2, hs: Vector2) -> bool:
	var c := Vector2(tx * T + T * 0.5, ty * T + T * 0.5)
	return absf(c.x - center.x) < hs.x + T * 0.5 and absf(c.y - center.y) < hs.y + T * 0.5


func _server_set_tile(room: RoomData, tx: int, ty: int, t: int) -> void:
	room.world.set_tile(tx, ty, t)
	for pid in room.peers:
		rpc_set_tile.rpc_id(pid, tx, ty, t)


# =====================================================================
#  RPCs: server -> client
# =====================================================================

@rpc("authority", "reliable")
func rpc_notice(message: String) -> void:
	menu.set_status(message)


@rpc("authority", "reliable")
func rpc_auth_ok(display_name: String) -> void:
	my_name = display_name
	menu.set_player(display_name)
	menu.show_rooms("")


@rpc("authority", "reliable")
func rpc_enter_room(code: String, display_name: String, tiles: PackedByteArray, spawn: Vector2, blocks: int) -> void:
	room_code = code
	my_name = display_name
	world.tiles = tiles
	world.queue_redraw()
	my_pos = spawn
	my_vel = Vector2.ZERO
	my_blocks = blocks
	my_invuln = true
	players_view.clear()
	worms_view.clear()
	camera.limit_left = 0
	camera.limit_right = WorldScript.W * T
	camera.limit_bottom = WorldScript.H * T
	camera.limit_top = -160
	camera.position = my_pos
	camera.reset_smoothing()
	in_game = true
	paused = false
	pause_menu.close()
	menu.visible = false
	_set_hud_visible(true)
	_refresh_touch()
	_toast("Room %s - tell your friends the code! Run from the worms!" % code)


@rpc("authority", "reliable")
func rpc_set_tile(tx: int, ty: int, t: int) -> void:
	world.set_tile(tx, ty, t)


@rpc("authority", "reliable")
func rpc_blocks(n: int) -> void:
	my_blocks = n


@rpc("authority", "reliable")
func rpc_caught(spawn: Vector2) -> void:
	if not in_game:
		return
	my_pos = spawn
	my_vel = Vector2.ZERO
	camera.position = my_pos
	camera.reset_smoothing()
	_toast("A worm got you! Back to spawn.")


@rpc("authority", "unreliable")
func rpc_snapshot(pl: Array, wm: Array) -> void:
	if not in_game:
		return
	var me_id := multiplayer.get_unique_id()

	var seen := {}
	for e in pl:
		var id: int = e[0]
		seen[id] = true
		var v: Dictionary
		if players_view.has(id):
			v = players_view[id]
		else:
			v = {"pos": e[2]}
			players_view[id] = v
		v["name"] = e[1]
		v["target"] = e[2]
		v["facing"] = e[3]
		v["deaths"] = e[4]
		v["best"] = e[5]
		v["alive"] = e[6]
		v["invuln"] = e[7]
		if id == me_id:
			my_invuln = e[7]
	for id in players_view.keys():
		if not seen.has(id):
			players_view.erase(id)

	var seen_w := {}
	for e in wm:
		var wid: int = e[0]
		seen_w[wid] = true
		var w: Dictionary
		if worms_view.has(wid):
			w = worms_view[wid]
		else:
			w = {"pos": e[1], "trail": []}
			worms_view[wid] = w
		w["target"] = e[1]
		w["facing"] = e[2]
		w["digging"] = e[3]
	for wid in worms_view.keys():
		if not seen_w.has(wid):
			worms_view.erase(wid)


# =====================================================================
#  Per-frame update
# =====================================================================

func _process(delta: float) -> void:
	delta = minf(delta, 0.033)
	if is_server:
		_server_tick(delta)
		return

	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_panel.visible = false

	var vs := get_viewport_rect().size
	rotate_overlay.visible = use_touch_ui and vs.y > vs.x * 1.1

	_client_connection_tick(delta)

	if in_game:
		_update_local_player(delta)
		_update_views(delta)
		_update_hud()
		queue_redraw()


func _update_local_player(delta: float) -> void:
	var left := false
	var right := false
	var jump := false
	if not paused:
		left = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
		right = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
		jump = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE)

	var dir := 0.0
	if left:
		dir -= 1.0
	if right:
		dir += 1.0
	if use_touch_ui and not paused:
		if touch.move_dir != 0.0:
			dir = touch.move_dir
		if touch.jump_held:
			jump = true
	if dir != 0.0:
		my_facing = int(dir)

	my_vel.x = move_toward(my_vel.x, dir * PLAYER_SPEED, 1400.0 * delta)
	my_vel.y = minf(my_vel.y + GRAVITY * delta, MAX_FALL)
	var r: Dictionary = world.move_box(my_pos, my_vel, PLAYER_HS, delta)
	my_pos = r["pos"]
	my_vel = r["vel"]
	if jump and r["floor"]:
		my_vel.y = -PLAYER_JUMP

	camera.position = my_pos

	# break / place blocks (mouse, or touch when touch controls are on)
	touch.blocks_text = str(my_blocks)
	var want_break := false
	var want_place := false
	if use_touch_ui:
		aim_world = get_canvas_transform().affine_inverse() * touch.aim_screen
		if not paused and touch.aim_active:
			want_place = touch.place_mode
			want_break = not touch.place_mode
	else:
		aim_world = get_global_mouse_position()
		if not paused:
			want_break = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			want_place = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	action_cd -= delta
	if action_cd <= 0.0 and (want_break or want_place):
		var tile: Vector2i = world.world_to_tile(aim_world)
		var c := Vector2(tile.x * T + T * 0.5, tile.y * T + T * 0.5)
		if my_pos.distance_to(c) <= REACH:
			var t: int = world.get_tile(tile.x, tile.y)
			if want_break and t != WorldScript.AIR and t != WorldScript.BEDROCK:
				rpc_break.rpc_id(1, tile.x, tile.y)
				action_cd = 0.12
			elif want_place and t == WorldScript.AIR and my_blocks > 0:
				rpc_place.rpc_id(1, tile.x, tile.y)
				action_cd = 0.12

	# tell the server where we are
	send_timer += delta
	if send_timer >= 0.05:
		send_timer = 0.0
		rpc_state.rpc_id(1, my_pos, my_facing)


func _update_views(delta: float) -> void:
	var k := 1.0 - exp(-18.0 * delta)
	for id in players_view:
		var v: Dictionary = players_view[id]
		v["pos"] = (v["pos"] as Vector2).lerp(v["target"], k)
	for wid in worms_view:
		var w: Dictionary = worms_view[wid]
		var np: Vector2 = (w["pos"] as Vector2).lerp(w["target"], k)
		w["pos"] = np
		var trail: Array = w["trail"]
		if trail.is_empty() or (trail[0] as Vector2).distance_to(np) > 7.0:
			trail.push_front(np)
			if trail.size() > 6:
				trail.pop_back()


func _update_hud() -> void:
	var me_id := multiplayer.get_unique_id()
	var st: Dictionary = {}
	if players_view.has(me_id):
		st = players_view[me_id]
	hud_label.text = "ROOM CODE: %s\n%s    Blocks: %d    Alive: %ds    Best: %ds    Caught: %d" % [
		room_code, my_name, my_blocks, int(st.get("alive", 0.0)), int(st.get("best", 0.0)), int(st.get("deaths", 0))]

	var rows := []
	for id in players_view:
		var v: Dictionary = players_view[id]
		rows.append([v["name"], maxf(v["best"], v["alive"]), v["deaths"]])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var txt := "Longest survival\n"
	for row in rows:
		txt += "%s  %ds  (caught %d)\n" % [row[0], int(row[1]), row[2]]
	board_label.text = txt


# =====================================================================
#  Server simulation (one pass per room)
# =====================================================================

func _server_tick(delta: float) -> void:
	for code in rooms:
		_tick_room(rooms[code], delta)


func _tick_room(room: RoomData, delta: float) -> void:
	if room.peers.is_empty():
		return

	for id in room.peers:
		var p: PlayerData = room.peers[id]
		p.alive += delta
		p.invuln = maxf(0.0, p.invuln - delta)

	for wid in room.worms:
		_tick_worm(room, room.worms[wid], delta)

	_check_catches(room)

	room.spawn_timer += delta
	if room.spawn_timer >= 1.5:
		room.spawn_timer = 0.0
		_manage_worm_count(room)

	room.snap_timer += delta
	if room.snap_timer >= 0.05:
		room.snap_timer = 0.0
		_broadcast_snapshot(room)


func _broadcast_snapshot(room: RoomData) -> void:
	var pl := []
	for id in room.peers:
		var p: PlayerData = room.peers[id]
		pl.append([id, p.uname, p.pos, p.facing, p.deaths, p.best, p.alive, p.invuln > 0.0])
	var wm := []
	for wid in room.worms:
		var w: WormData = room.worms[wid]
		wm.append([w.id, w.pos, w.facing, w.digging])
	for id in room.peers:
		rpc_snapshot.rpc_id(id, pl, wm)


func _tick_worm(room: RoomData, w: WormData, delta: float) -> void:
	# pick the nearest visible player
	var target := Vector2.ZERO
	var has_target := false
	var best := WORM_SIGHT
	for id in room.peers:
		var p: PlayerData = room.peers[id]
		if p.invuln > 0.0:
			continue
		var d := w.pos.distance_to(p.pos)
		if d < best:
			best = d
			target = p.pos
			has_target = true

	var dir := 0
	var speed := WORM_SPEED_WANDER
	if has_target:
		speed = WORM_SPEED_CHASE
		var dx := target.x - w.pos.x
		if absf(dx) > 3.0:
			dir = 1 if dx > 0.0 else -1
	else:
		w.wander_t -= delta
		if w.wander_t <= 0.0:
			w.wander_t = randf_range(1.0, 3.0)
			w.wander_dir = randi_range(-1, 1)
		dir = w.wander_dir
	if dir != 0:
		w.facing = dir
	w.vel.x = dir * speed

	# climb walls toward a player above, otherwise fall
	var climbing := has_target and target.y < w.pos.y - 10.0 and w.hit_wall and dir != 0
	if climbing:
		w.vel.y = -WORM_CLIMB
	else:
		w.vel.y = minf(w.vel.y + GRAVITY * delta, MAX_FALL)

	# hop over one-block steps, dig through anything taller
	var dig_mode := 0   # 0 = none, 1 = dig forward, 2 = dig upward
	if w.hit_wall and dir != 0 and w.on_floor and not climbing:
		if room.world.box_hits(w.pos + Vector2(dir * 2.0, -float(T)), WORM_HS):
			dig_mode = 1
		else:
			w.vel.y = -WORM_JUMP
	elif climbing and w.hit_ceiling:
		dig_mode = 2

	var r: Dictionary = room.world.move_box(w.pos, w.vel, WORM_HS, delta)
	w.pos = r["pos"]
	w.vel = r["vel"]
	w.on_floor = r["floor"]
	w.hit_wall = r["wall"]
	w.hit_ceiling = r["ceiling"]

	w.digging = dig_mode != 0
	if dig_mode == 0:
		w.dig_t = 0.0
	else:
		w.dig_t += delta
		if w.dig_t >= WORM_DIG_TIME:
			w.dig_t = 0.0
			_worm_dig(room, w, dir, dig_mode)


func _worm_dig(room: RoomData, w: WormData, dir: int, mode: int) -> void:
	if mode == 1:
		var tx := floori((w.pos.x + dir * (WORM_HS.x + 2.0)) / T)
		var y0 := floori((w.pos.y - WORM_HS.y) / T)
		var y1 := floori((w.pos.y + WORM_HS.y - 0.01) / T)
		for ty in range(y0, y1 + 1):
			_worm_break(room, tx, ty)
	else:
		var ty := floori((w.pos.y - WORM_HS.y - 2.0) / T)
		var x0 := floori((w.pos.x - WORM_HS.x) / T)
		var x1 := floori((w.pos.x + WORM_HS.x - 0.01) / T)
		for tx in range(x0, x1 + 1):
			_worm_break(room, tx, ty)


func _worm_break(room: RoomData, tx: int, ty: int) -> void:
	if not room.world.in_bounds(tx, ty):
		return
	var t: int = room.world.get_tile(tx, ty)
	if t == WorldScript.AIR or t == WorldScript.BEDROCK:
		return
	_server_set_tile(room, tx, ty, WorldScript.AIR)


func _check_catches(room: RoomData) -> void:
	for id in room.peers:
		var p: PlayerData = room.peers[id]
		if p.invuln > 0.0:
			continue
		for wid in room.worms:
			var w: WormData = room.worms[wid]
			if absf(w.pos.x - p.pos.x) < WORM_HS.x + PLAYER_HS.x and absf(w.pos.y - p.pos.y) < WORM_HS.y + PLAYER_HS.y:
				_catch(room, id, p)
				break


func _catch(room: RoomData, id: int, p: PlayerData) -> void:
	p.deaths += 1
	p.best = maxf(p.best, p.alive)
	p.alive = 0.0
	p.invuln = 3.0
	p.pos = _spawn_point(room)
	rpc_caught.rpc_id(id, p.pos)


func _manage_worm_count(room: RoomData) -> void:
	var want := clampi(3 + room.peers.size() * 2, 0, 12)
	while room.worms.size() < want:
		_spawn_worm(room)
	while room.worms.size() > want:
		room.worms.erase(room.worms.keys().back())


func _spawn_worm(room: RoomData) -> void:
	# try a few spots on the surface, keep the one farthest from all players
	var best_pos := Vector2(T * 4, T * 10)
	var best_d := -1.0
	for i in range(8):
		var tx := randi_range(3, WorldScript.W - 4)
		var sy: int = room.world.surface_y(tx)
		var pos := Vector2(tx * T + T * 0.5, sy * T - 6.0)
		var nearest := 99999.0
		for id in room.peers:
			var p: PlayerData = room.peers[id]
			nearest = minf(nearest, pos.distance_to(p.pos))
		if nearest > best_d:
			best_d = nearest
			best_pos = pos
	var w := WormData.new()
	w.id = room.next_worm_id
	room.next_worm_id += 1
	w.pos = best_pos
	room.worms[w.id] = w


func _spawn_point(room: RoomData) -> Vector2:
	var cx := int(WorldScript.W * 0.5) + randi_range(-8, 8)
	var sy: int = room.world.surface_y(cx)
	var pos := Vector2(cx * T + T * 0.5, sy * T - 8.0)
	var tries := 0
	while room.world.box_hits(pos, PLAYER_HS) and tries < 40:
		pos.y -= T
		tries += 1
	return pos


# =====================================================================
#  Drawing (players, worms, cursor) - client only
# =====================================================================

func _draw() -> void:
	if not in_game:
		return
	var font := ThemeDB.fallback_font
	var me_id := multiplayer.get_unique_id()

	for wid in worms_view:
		_draw_worm(worms_view[wid])

	for id in players_view:
		if id == me_id:
			continue
		var v: Dictionary = players_view[id]
		_draw_player(v["pos"], v["facing"], v["name"], v["invuln"], font)
	_draw_player(my_pos, my_facing, my_name, my_invuln, font)

	# block cursor
	if paused or (use_touch_ui and not touch.aim_active):
		return
	var tile: Vector2i = world.world_to_tile(aim_world)
	var c := Vector2(tile.x * T + T * 0.5, tile.y * T + T * 0.5)
	var ok := my_pos.distance_to(c) <= REACH
	var col := Color(1, 1, 1, 0.9) if ok else Color(1, 0.3, 0.3, 0.6)
	draw_rect(Rect2(tile.x * T, tile.y * T, T, T), col, false, 1.0)


func _draw_player(pos: Vector2, facing: int, uname: String, invuln: bool, font: Font) -> void:
	var col := Color.from_hsv(float(uname.hash() % 360) / 360.0, 0.55, 0.95)
	if invuln and Time.get_ticks_msec() % 300 < 150:
		col.a = 0.35
	draw_rect(Rect2(pos - PLAYER_HS, PLAYER_HS * 2.0), col)
	var eye := pos + Vector2(facing * 2.5, -3.0)
	draw_circle(eye, 2.0, Color.WHITE)
	draw_circle(eye + Vector2(facing * 0.8, 0.0), 1.0, Color.BLACK)
	draw_string(font, pos + Vector2(-60.0, -12.0), uname, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, Color.WHITE)


func _draw_worm(w: Dictionary) -> void:
	var trail: Array = w["trail"]
	var pos: Vector2 = w["pos"]
	var facing: int = w["facing"]
	var n := trail.size()
	for i in range(n - 1, -1, -1):
		var r := lerpf(7.0, 4.0, float(i) / 6.0)
		draw_circle(trail[i], r, Color(0.85, 0.45, 0.5).darkened(0.04 * i))
	var head_col := Color(0.95, 0.55, 0.6)
	if w["digging"]:
		head_col = Color(0.8, 0.35, 0.3)
	draw_circle(pos, 8.0, head_col)
	var eye := pos + Vector2(facing * 3.5, -2.5)
	draw_circle(eye, 2.5, Color.WHITE)
	draw_circle(eye + Vector2(facing * 1.0, 0.0), 1.2, Color.BLACK)
