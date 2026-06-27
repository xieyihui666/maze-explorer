extends Node2D

const CELL = 48
const VIEW_RANGE = 4
var maze = []
var explored = []
var exit_pos = Vector2i.ZERO
var spawn_pos = Vector2i.ZERO
var player_pos = Vector2.ZERO
var time_left = 600.0
var game_over = false
var won = false
var show_map = false
var path: Array = []
var path_index: int = 0
var cheat_open: bool = false
var noclip: bool = false
var cheat_teleport: bool = false
var items: Array = []
var inventory: Array = [0, 0, 0, 0, 0]
var speed_mult: float = 1.0
var mouse_guide: bool = false
var paused: bool = false
var show_help: bool = false
var item_timers: Dictionary = {}
var VIEW_RANGE_PERM: int = 0
var peer_pos: Vector2 = Vector2.ZERO
var sync_timer: float = 0.0
var is_multi: bool = false
var is_host: bool = false
var is_race: bool = false
var maze_ready: bool = true
var time_sync_timer: float = 0.0
var disconnected: bool = false
var peer_connected: bool = false
var connecting: bool = false
var connect_attempts: int = 0
var flash_alpha: float = 0.0
var flash_color: Color = Color.WHITE
var particles: Array = []
var exit_pulse: float = 0.0
var camera_zoom_target: float = 1.8
var loading: bool = false

enum ItemType { SPEED = 0, TIME = 1, WALL_BREAK = 2, MINIMAP = 3, VISION_UP = 4 }

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	is_multi = GameState.is_multi
	is_host = GameState.is_host
	is_race = GameState.is_race
	if is_multi:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		peer_connected = false
	if is_multi and not is_host:
		maze_ready = false
		connecting = true
		NetworkManager.start_client(GameState.join_ip)
	else:
		generate_maze()
		if is_multi:
			$HUD/StatusLabel.text = "等待好友加入..."
			$HUD/StatusLabel.visible = true
	player_pos = Vector2(spawn_pos.x * CELL + CELL/2, spawn_pos.y * CELL + CELL/2)
	$Camera2D.global_position = player_pos
	$HUD/PauseMenu.visible = false
	$HUD/HelpPanel.visible = false
	$HUD/PauseMenu/RestartBtn.pressed.connect(func(): get_tree().reload_current_scene())
	$HUD/PauseMenu/MenuBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Start.tscn"))

func generate_maze():
	VIEW_RANGE_PERM = 0
	items.clear()
	item_timers.clear()
	speed_mult = 1.0
	inventory = [0, 0, 0, 0, 0]
	particles.clear()
	flash_alpha = 0.0
	var sz = GameState.maze_size
	if sz >= 140:
		loading = true
		$HUD/StatusLabel.text = "生成迷宫中..."
		$HUD/StatusLabel.visible = true
		await get_tree().process_frame
	maze.clear()
	explored.clear()
	for y in range(sz):
		maze.append([])
		explored.append([])
		for x in range(sz):
			maze[y].append(true)
			explored[y].append(false)

	var stack = []
	var start = Vector2i(1, 1)
	maze[start.y][start.x] = false
	stack.append(start)
	var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

	while not stack.is_empty():
		var current = stack.back()
		var neighbors: Array = []
		for d in dirs:
			var nx = current.x + d.x * 2
			var ny = current.y + d.y * 2
			if nx > 0 and nx < sz - 1 and ny > 0 and ny < sz - 1:
				if maze[ny][nx]:
					neighbors.append(Vector2i(nx, ny))
		if neighbors.is_empty():
			stack.pop_back()
		else:
			var next = neighbors[randi() % neighbors.size()]
			maze[(current.y + next.y) / 2][(current.x + next.x) / 2] = false
			maze[next.y][next.x] = false
			stack.append(next)

	spawn_pos = Vector2i(1, 1)
	exit_pos = Vector2i(sz - 3, sz - 3)
	if maze[exit_pos.y][exit_pos.x]:
		exit_pos = Vector2i(sz - 3, sz - 2)
	if maze[exit_pos.y][exit_pos.x]:
		exit_pos = Vector2i(sz - 2, sz - 3)

	for i in range(int(sz * sz * 0.03)):
		var x = randi_range(2, sz - 3)
		var y = randi_range(2, sz - 3)
		if maze[y][x]:
			var cnt = 0
			for d in dirs:
				if not maze[y + d.y][x + d.x]:
					cnt += 1
			if cnt >= 2:
				maze[y][x] = false

	loading = false
	$HUD/StatusLabel.visible = false
	spawn_items()

func spawn_items():
	items.clear()
	if GameState.item_count <= 0:
		return
	var types = [ItemType.SPEED, ItemType.TIME, ItemType.WALL_BREAK, ItemType.MINIMAP, ItemType.VISION_UP]
	var sz = GameState.maze_size
	for i in range(GameState.item_count):
		var t = types[randi() % types.size()]
		for attempt in range(100):
			var cx = randi_range(2, sz - 3)
			var cy = randi_range(2, sz - 3)
			if not maze[cy][cx]:
				if cx != spawn_pos.x or cy != spawn_pos.y:
					if cx != exit_pos.x or cy != exit_pos.y:
						items.append({"pos": Vector2(cx * CELL + CELL/2, cy * CELL + CELL/2), "type": t})
						break

func _on_peer_connected(id: int):
	if is_host:
		rcv_maze.rpc_id(id, maze, exit_pos.x, exit_pos.y, spawn_pos.x, spawn_pos.y, GameState.maze_size)
		send_items.rpc_id(id, items)
		peer_connected = true
		$HUD/StatusLabel.visible = false
	else:
		peer_connected = true
		connecting = false

@rpc("authority", "reliable")
func rcv_maze(mz: Array, ex: int, ey: int, spx: int, spy: int, sz: int):
	if not is_host:
		maze = mz
		exit_pos = Vector2i(ex, ey)
		spawn_pos = Vector2i(spx, spy)
		GameState.maze_size = sz
		explored.clear()
		for y in range(sz):
			explored.append([])
			for x in range(sz):
				explored[y].append(false)
		maze_ready = true
		player_pos = Vector2(spawn_pos.x * CELL + CELL/2, spawn_pos.y * CELL + CELL/2)

@rpc("any_peer", "unreliable_ordered")
func sync_position(pos: Vector2):
	var sender = multiplayer.get_remote_sender_id()
	if sender == 1 and not is_host:
		pass
	peer_pos = pos

@rpc("authority")
func send_items(itms: Array):
	if not is_host:
		items = itms

@rpc("authority", "reliable")
func sync_time(tl: float):
	if not is_host:
		time_left = tl

@rpc("any_peer", "reliable")
func sync_item_use(type: int):
	apply_item_effect(type)
	update_hud()

@rpc("any_peer", "reliable")
func sync_wall_break(pos: Vector2):
	var old = player_pos
	player_pos = pos
	break_walls_near_player()
	player_pos = old

@rpc("any_peer", "reliable")
func sync_item_remove(idx: int):
	if idx >= 0 and idx < items.size():
		items.remove_at(idx)

@rpc("any_peer", "reliable")
func sync_race_win():
	game_over = true
	if multiplayer.get_remote_sender_id() == 0:
		won = true
	else:
		won = false
	update_hud()

func _on_peer_disconnected(_id: int):
	disconnected = true
	game_over = true
	$HUD/GameOver.visible = true
	$HUD/GameOver/Title.text = "队友断开连接"
	$HUD/GameOver/Score.text = ""
	$HUD/GameOver/Hint.text = "按 Enter 返回主菜单"

func _process(delta):
	if disconnected:
		return
	if connecting:
		connect_attempts += 1
		if connect_attempts > 300:
			connecting = false
			disconnected = true
			$HUD/GameOver.visible = true
			$HUD/GameOver/Title.text = "连接超时"
			$HUD/GameOver/Score.text = ""
			$HUD/GameOver/Hint.text = "按 Enter 返回主菜单"
		else:
			$HUD/StatusLabel.text = "正在连接... %d" % (connect_attempts / 60)
			$HUD/StatusLabel.visible = true
		return
	if not maze_ready:
		return
	if is_multi and not peer_connected:
		return
	if game_over or show_map or paused or show_help:
		if show_map:
			$HUD/BigMap.queue_redraw()
		flash_alpha = move_toward(flash_alpha, 0, delta * 3)
		queue_redraw()
		return

	flash_alpha = move_toward(flash_alpha, 0, delta * 3)
	exit_pulse += delta * 3
	camera_zoom_target = 2.0 if speed_mult > 1.5 else 1.8
	$Camera2D.zoom = $Camera2D.zoom.lerp(Vector2(camera_zoom_target, camera_zoom_target), delta * 4)
	update_particles(delta)

	time_left -= delta
	if time_left <= 0:
		time_left = 0
		game_over = true
		update_hud()
		return

	if path.size() > 0 and path_index < path.size():
		var target = path[path_index]
		var to_target = target - player_pos
		if to_target.length() < 4:
			path_index += 1
		else:
			player_pos += to_target.normalized() * 260 * delta * speed_mult
	else:
		var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if dir != Vector2.ZERO:
			path.clear()
		var spd = 260 * delta * speed_mult
		var nx = player_pos.x + dir.x * spd
		if is_passable(Vector2(nx, player_pos.y)):
			player_pos.x = nx
		var ny = player_pos.y + dir.y * spd
		if is_passable(Vector2(player_pos.x, ny)):
			player_pos.y = ny

	$Camera2D.global_position = player_pos
	$HUD/MiniMap.update_data(explored, maze, GameState.maze_size, player_pos, exit_pos, CELL, items)
	check_items()
	update_timers(delta)

	var pcx = int(player_pos.x / CELL)
	var pcy = int(player_pos.y / CELL)
	if pcx == exit_pos.x and pcy == exit_pos.y:
		if is_multi and is_race:
			sync_race_win.rpc()
		else:
			game_over = true
			won = true

	update_hud()
	queue_redraw()

	if is_multi:
		sync_timer += delta
		if sync_timer > 0.05:
			sync_timer = 0.0
			sync_position.rpc(player_pos)
		if is_host:
			time_sync_timer += delta
			if time_sync_timer > 1.0:
				time_sync_timer = 0.0
				sync_time.rpc(time_left)

func is_passable(pos: Vector2) -> bool:
	var sz = GameState.maze_size
	if noclip:
		return true
	for c in [Vector2(pos.x-10, pos.y-10), Vector2(pos.x+10, pos.y-10), Vector2(pos.x-10, pos.y+10), Vector2(pos.x+10, pos.y+10)]:
		var cx = int(c.x / CELL)
		var cy = int(c.y / CELL)
		if cx < 0 or cx >= sz or cy < 0 or cy >= sz:
			return false
		if maze[cy][cx]:
			return false
	return true

func _draw():
	if maze.is_empty():
		return
	var sz = GameState.maze_size
	var vs = get_viewport().get_visible_rect().size / $Camera2D.zoom
	var cp = $Camera2D.global_position
	var sx = max(0, int((cp.x - vs.x/2) / CELL))
	var sy = max(0, int((cp.y - vs.y/2) / CELL))
	var ex = min(sz - 1, int((cp.x + vs.x/2) / CELL) + 1)
	var ey = min(sz - 1, int((cp.y + vs.y/2) / CELL) + 1)
	var pcx = int(player_pos.x / CELL)
	var pcy = int(player_pos.y / CELL)

	for y in range(sy, ey + 1):
		for x in range(sx, ex + 1):
			var dist = abs(x - pcx) + abs(y - pcy)
			if dist <= VIEW_RANGE + VIEW_RANGE_PERM:
				var c = Color(0.22, 0.25, 0.35) if maze[y][x] else Color(0.35, 0.32, 0.28)
				draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), c)

	var gx = exit_pos.x * CELL
	var gy = exit_pos.y * CELL
	if abs(exit_pos.x - pcx) + abs(exit_pos.y - pcy) <= VIEW_RANGE + VIEW_RANGE_PERM:
		draw_rect(Rect2(gx + 4, gy + 4, CELL - 8, CELL - 8), Color(0.15, 0.7, 0.25))

	draw_circle(player_pos, 10, Color(0.3, 0.6, 1))

	if is_multi and peer_pos != Vector2.ZERO:
		draw_circle(peer_pos, 10, Color(1, 0.4, 0.3))

	for p in particles:
		draw_circle(p["pos"], p["size"], Color(p["color"], p["life"] * 2))

	if flash_alpha > 0.01:
		draw_rect(Rect2(0, 0, get_viewport().get_visible_rect().size.x * 10, get_viewport().get_visible_rect().size.y * 10), Color(flash_color, flash_alpha), true)

	if game_over and not is_race:
		var pulse = sin(exit_pulse) * 0.3 + 0.7
		draw_rect(Rect2(gx + 4, gy + 4, CELL - 8, CELL - 8), Color(0.15, 0.7, 0.25, pulse))

	for item in items:
		var ix = int(item["pos"].x / CELL)
		var iy = int(item["pos"].y / CELL)
		if abs(ix - pcx) + abs(iy - pcy) <= VIEW_RANGE + VIEW_RANGE_PERM:
			draw_item_shape(item["pos"], item["type"])

func draw_item_shape(pos: Vector2, type: int):
	var s = 6
	match type:
		ItemType.SPEED:
			draw_rect(Rect2(pos.x - 2, pos.y - s, 4, s * 2), Color(1, 0.9, 0.2))
			draw_rect(Rect2(pos.x - 3, pos.y - 2, 2, s + 2), Color(1, 0.8, 0))
			draw_rect(Rect2(pos.x + 1, pos.y + 2, 2, s - 4), Color(1, 0.8, 0))
		ItemType.TIME:
			draw_rect(Rect2(pos.x - 1, pos.y - s, 2, 4), Color(0.3, 0.9, 0.4))
			draw_rect(Rect2(pos.x - 1, pos.y + s - 4, 2, 4), Color(0.3, 0.9, 0.4))
			draw_circle(Vector2(pos.x, pos.y - s + 2), 2, Color(0.2, 0.8, 0.3))
			draw_circle(Vector2(pos.x, pos.y + s - 3), 2, Color(0.2, 0.8, 0.3))
		ItemType.WALL_BREAK:
			draw_rect(Rect2(pos.x - 1, pos.y - s, 2, s * 2), Color(0.6, 0.3, 0.1))
			draw_rect(Rect2(pos.x - s, pos.y - s - 3, s * 2, 6), Color(0.85, 0.3, 0.2))
		ItemType.MINIMAP:
			for a in range(0, 360, 120):
				var r = Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * 4
				draw_circle(pos + r, 3, Color(0.2, 0.85, 0.3))
			draw_circle(pos, 2, Color(0.1, 0.7, 0.2))
		ItemType.VISION_UP:
			draw_rect(Rect2(pos.x - s, pos.y - 4, s * 2, 8), Color(1, 0.95, 0.3))
			draw_circle(Vector2(pos.x, pos.y), 3, Color(0.1, 0.1, 0.2))
			draw_circle(Vector2(pos.x, pos.y), 1.5, Color.WHITE)

func update_hud():
	var mins = int(time_left / 60)
	var secs = int(time_left) % 60
	$HUD/Timer.text = "%02d:%02d" % [mins, secs]
	if time_left < 60:
		$HUD/Timer.add_theme_color_override("font_color", Color.RED)

	var inv_text = "[1]⚡%d [2]⌛%d [3]🔨%d [4]🍀%d [5]👁%d" % [inventory[0], inventory[1], inventory[2], inventory[3], inventory[4]]
	$HUD/Inventory.text = inv_text

	if game_over:
		$HUD/GameOver.visible = true
		if is_race:
			if won:
				$HUD/GameOver/Title.text = "你赢了!"
			else:
				$HUD/GameOver/Title.text = "你输了!"
			$HUD/GameOver/Score.text = ""
		elif won:
			$HUD/GameOver/Title.text = "恭喜通关!"
			$HUD/GameOver/Score.text = "得分: %d" % (int(time_left) * 10)
		else:
			$HUD/GameOver/Title.text = "时间耗尽!"

func check_items():
	var to_remove = []
	for i in range(items.size()):
		var item = items[i]
		if player_pos.distance_to(item["pos"]) < 20:
			to_remove.append(i)
			inventory[item["type"]] += 1
			spawn_particles(item["pos"], item["type"])
			flash_alpha = 0.3
			match item["type"]:
				ItemType.SPEED: flash_color = Color.CYAN
				ItemType.TIME: flash_color = Color.GREEN
				ItemType.WALL_BREAK: flash_color = Color.RED
				ItemType.MINIMAP: flash_color = Color.MAGENTA
				ItemType.VISION_UP: flash_color = Color.YELLOW
			if is_multi:
				sync_item_remove.rpc(i)
			update_hud()
	for i in range(to_remove.size() - 1, -1, -1):
		items.remove_at(to_remove[i])

func update_timers(delta):
	for key in item_timers.keys():
		item_timers[key] -= delta
		if item_timers[key] <= 0:
			match key:
				"speed": speed_mult = 1.0
				"minimap":
					for y in range(GameState.maze_size):
						for x in range(GameState.maze_size):
							explored[y][x] = false
			item_timers.erase(key)

func break_walls_near_player():
	var sz = GameState.maze_size
	var pcx = int(player_pos.x / CELL)
	var pcy = int(player_pos.y / CELL)
	var count = 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cx = pcx + dx
			var cy = pcy + dy
			if cx > 1 and cx < sz - 2 and cy > 1 and cy < sz - 2:
				if maze[cy][cx]:
					maze[cy][cx] = false
					count += 1
	if count > 0:
		flash_alpha = 0.5
		flash_color = Color.RED
		for i in range(count * 3):
			var ppos = Vector2(pcx * CELL + randf() * CELL * 5 - CELL * 2, pcy * CELL + randf() * CELL * 5 - CELL * 2)
			spawn_particles(ppos, ItemType.WALL_BREAK)

func spawn_particles(pos: Vector2, type: int):
	var colors = [Color.CYAN, Color.GREEN, Color.RED, Color.MAGENTA, Color.YELLOW]
	var c = colors[type]
	for i in range(8):
		var angle = randf() * TAU
		var speed = randf_range(40, 120)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.3, 0.8),
			"color": c,
			"size": randf_range(2, 5)
		})

func update_particles(delta):
	var to_remove = []
	for i in range(particles.size()):
		var p = particles[i]
		p["life"] -= delta
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.95
		if p["life"] <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		particles.remove_at(to_remove[i])

func _input(event):
	if show_map:
		if event.is_action_pressed("ui_cancel"):
			show_map = false
			$HUD/BigMap.visible = false
		return

	if show_help:
		if event.is_action_pressed("ui_cancel"):
			show_help = false
			$HUD/HelpPanel.visible = false
		return

	if paused:
		if event.is_action_pressed("ui_cancel"):
			paused = false
			$HUD/PauseMenu.visible = false
		return

	if cheat_open:
		if event.is_action_pressed("ui_accept"):
			close_cheat()
		elif event.is_action_pressed("ui_cancel"):
			cheat_open = false
			$HUD/CheatPanel.visible = false
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		open_cheat()
		return

	if event.is_action_pressed("ui_cancel") and not game_over:
		paused = true
		$HUD/PauseMenu.visible = true
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		show_help = true
		$HUD/HelpPanel.visible = true
		return

	if show_map:
		if event.is_action_pressed("ui_cancel"):
			show_map = false
			$HUD/BigMap.visible = false
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos = $HUD/MiniMap.get_local_mouse_position()
		if mpos.x >= 0 and mpos.x <= 180 and mpos.y >= 0 and mpos.y <= 180:
			if cheat_teleport:
				teleport_via_minimap(mpos)
				return
			show_map = true
			$HUD/BigMap.visible = true
			$HUD/BigMap.init_data(explored, maze, GameState.maze_size, player_pos, exit_pos, CELL, items)
			return
		else:
			if mouse_guide:
				move_to_click(event.global_position)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_guide:
			move_to_click(event.global_position)

	if event.is_action_pressed("ui_accept") and game_over:
		get_tree().change_scene_to_file("res://scenes/Start.tscn")

	if event is InputEventKey and event.pressed and not game_over and not paused:
		match event.keycode:
			KEY_1: use_item(0)
			KEY_2: use_item(1)
			KEY_3: use_item(2)
			KEY_4: use_item(3)
			KEY_5: use_item(4)
			KEY_E:
				if is_multi and peer_pos != Vector2.ZERO:
					player_pos = peer_pos
					path.clear()

func use_item(type: int):
	if inventory[type] <= 0:
		return
	inventory[type] -= 1
	if is_multi:
		if type == ItemType.WALL_BREAK:
			sync_wall_break.rpc(player_pos)
		elif type == ItemType.TIME:
			if is_host:
				time_left += 60
		else:
			sync_item_use.rpc(type)
	else:
		apply_item_effect(type)
	update_hud()

func apply_item_effect(type: int):
	match type:
		ItemType.SPEED:
			speed_mult = 2.0
			item_timers["speed"] = 10.0
		ItemType.WALL_BREAK:
			break_walls_near_player()
		ItemType.MINIMAP:
			for y in range(GameState.maze_size):
				for x in range(GameState.maze_size):
					explored[y][x] = true
			item_timers["minimap"] = 5.0
		ItemType.VISION_UP:
			VIEW_RANGE_PERM += 2

func move_to_click(screen_pos: Vector2):
	if game_over or show_map:
		return
	var world_pos = $Camera2D.get_screen_center_position() + (screen_pos - get_viewport().get_visible_rect().size / 2) / $Camera2D.zoom
	var tx = int(world_pos.x / CELL)
	var ty = int(world_pos.y / CELL)
	var sz = GameState.maze_size
	if tx < 0 or tx >= sz or ty < 0 or ty >= sz or maze[ty][tx]:
		return
	var from = Vector2i(int(player_pos.x / CELL), int(player_pos.y / CELL))
	var to = Vector2i(tx, ty)
	path = find_path(from, to)
	path_index = 0

func teleport_via_minimap(mpos: Vector2):
	var sz = GameState.maze_size
	var s = 180.0 / float(sz)
	var cx = int(mpos.x / s)
	var cy = int(mpos.y / s)
	if cx >= 0 and cx < sz and cy >= 0 and cy < sz and not maze[cy][cx]:
		player_pos = Vector2(cx * CELL + CELL/2, cy * CELL + CELL/2)
		path.clear()
	cheat_teleport = false

func find_path(from: Vector2i, to: Vector2i) -> Array:
	var sz = GameState.maze_size
	var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var open = []
	var came_from = {}
	var g_score = {}
	var f_score = {}
	var from_key = str(from.x) + "," + str(from.y)
	g_score[from_key] = 0
	f_score[from_key] = abs(from.x - to.x) + abs(from.y - to.y)
	open.append({"pos": from, "f": f_score[from_key]})

	while not open.is_empty():
		open.sort_custom(func(a, b): return a["f"] < b["f"])
		var current = open.pop_front()["pos"]
		var ck = str(current.x) + "," + str(current.y)
		if current == to:
			var result: Array = []
			var node = current
			while node != from:
				result.push_front(Vector2(node.x * CELL + CELL/2, node.y * CELL + CELL/2))
				var nk = str(node.x) + "," + str(node.y)
				node = came_from[nk]
			return result

		for d in dirs:
			var nx = current.x + d.x
			var ny = current.y + d.y
			if nx < 0 or nx >= sz or ny < 0 or ny >= sz:
				continue
			if maze[ny][nx]:
				continue
			var nk = str(nx) + "," + str(ny)
			var tent_g = g_score.get(ck, 99999) + 1
			if tent_g < g_score.get(nk, 99999):
				came_from[nk] = current
				g_score[nk] = tent_g
				f_score[nk] = tent_g + abs(nx - to.x) + abs(ny - to.y)
				var found = false
				for item in open:
					if item["pos"] == Vector2i(nx, ny):
						item["f"] = f_score[nk]
						found = true
						break
				if not found:
					open.append({"pos": Vector2i(nx, ny), "f": f_score[nk]})
	return []

func open_cheat():
	cheat_open = true
	$HUD/CheatPanel.visible = true
	$HUD/CheatPanel/Input.text = ""
	$HUD/CheatPanel/Input.grab_focus()

func close_cheat():
	cheat_open = false
	$HUD/CheatPanel.visible = false
	var code = $HUD/CheatPanel/Input.text.strip_edges().to_lower()
	exec_cheat(code)

func exec_cheat(code: String):
	if code == "showmap" or code == "xieyihui":
		for y in range(GameState.maze_size):
			for x in range(GameState.maze_size):
				explored[y][x] = true
	elif code == "noclip" or code == "chuanqiang":
		noclip = not noclip
	elif code.begins_with("time"):
		var parts = code.split(" ")
		if parts.size() >= 2 and parts[1].is_valid_int():
			time_left += int(parts[1])
	elif code == "shengli":
		player_pos = Vector2(exit_pos.x * CELL + CELL/2, exit_pos.y * CELL + CELL/2)
		game_over = true
		won = true
		update_hud()
	elif code == "shunyi":
		cheat_teleport = true
	elif code == "shubiao":
		mouse_guide = not mouse_guide
	$HUD/CheatPanel/Input.release_focus()
