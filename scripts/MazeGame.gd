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

enum ItemType { SPEED = 0, TIME = 1, WALL_BREAK = 2, MINIMAP = 3, VISION_UP = 4 }

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	generate_maze()
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
	var sz = GameState.maze_size
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

func _process(delta):
	if game_over or show_map or paused or show_help:
		if show_map:
			$HUD/BigMap.queue_redraw()
		return

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
		game_over = true
		won = true

	update_hud()
	queue_redraw()

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
		if won:
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
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cx = pcx + dx
			var cy = pcy + dy
			if cx > 1 and cx < sz - 2 and cy > 1 and cy < sz - 2:
				if maze[cy][cx]:
					maze[cy][cx] = false

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

func use_item(type: int):
	if inventory[type] <= 0:
		return
	inventory[type] -= 1
	match type:
		ItemType.SPEED:
			speed_mult = 2.0
			item_timers["speed"] = 10.0
		ItemType.TIME:
			time_left += 60
		ItemType.WALL_BREAK:
			break_walls_near_player()
		ItemType.MINIMAP:
			for y in range(GameState.maze_size):
				for x in range(GameState.maze_size):
					explored[y][x] = true
			item_timers["minimap"] = 5.0
		ItemType.VISION_UP:
			VIEW_RANGE_PERM += 2
	update_hud()

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
