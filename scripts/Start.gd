extends Node2D

var modes = [
	{"name": "⚡ 速通 10分钟", "time": 600, "size": 80, "items": 0, "enemies": 0},
	{"name": "🎯 标准 30分钟", "time": 1800, "size": 140, "items": 12, "enemies": 0},
	{"name": "🏰 深度 60分钟", "time": 3600, "size": 200, "items": 20, "enemies": 6},
]
var selected = 0
var show_lb = false
var show_exit = false
var show_help = false

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	$UI/BG.size = DisplayServer.screen_get_size()
	$UI/ExitPanel.visible = false
	$UI/HelpPanel.visible = false
	$UI/ExitPanel/QuitBtn.pressed.connect(func(): get_tree().quit())
	$UI/ExitPanel/ContinueBtn.pressed.connect(func(): show_exit = false; $UI/ExitPanel.visible = false)
	for i in 3:
		var row = $UI/Rows.get_child(i)
		row.gui_input.connect(_on_row_click.bind(i))
	update_ui()

func update_ui():
	for i in 3:
		var row = $UI/Rows.get_child(i)
		row.get_node("BG").color = Color(0.5, 0.5, 0.5, 0.5) if i == selected else Color(0.15, 0.15, 0.2, 0.5)
		row.get_node("Name").text = modes[i]["name"]
		var sz = modes[i]["size"]
		row.get_node("Info").text = "迷宫 %dx%d  |  %d分钟" % [sz, sz, modes[i]["time"]/60]
	if show_lb:
		$UI/LB.visible = true
		$UI/LB/Title.text = modes[selected]["name"] + " 排行榜"
		var scores = Leaderboard.get_top(selected)
		var txt = ""
		if scores.is_empty():
			txt = "暂无记录"
		else:
			for j in scores.size():
				txt += "%d. %s  %d分\n" % [j+1, scores[j]["name"], scores[j]["score"]]
		$UI/LB/List.text = txt
	else:
		$UI/LB.visible = false

func _on_row_click(event: InputEvent, idx: int):
	if show_exit or show_lb:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected == idx:
			start_game()
		else:
			selected = idx
			update_ui()

func _input(event):
	if show_help:
		if event.is_action_pressed("ui_cancel"):
			show_help = false
			$UI/HelpPanel.visible = false
		return

	if show_exit:
		if event.is_action_pressed("ui_cancel"):
			show_exit = false
			$UI/ExitPanel.visible = false
		return

	if show_lb:
		if event.is_action_pressed("p1_ultimate") or event.is_action_pressed("ui_cancel"):
			show_lb = false
			update_ui()
		elif event.is_action_pressed("move_left"):
			selected = wrapi(selected - 1, 0, 3)
			update_ui()
		elif event.is_action_pressed("move_right"):
			selected = wrapi(selected + 1, 0, 3)
			update_ui()
		return

	if event.is_action_pressed("move_up"):
		selected = wrapi(selected - 1, 0, 3)
		update_ui()
	elif event.is_action_pressed("move_down"):
		selected = wrapi(selected + 1, 0, 3)
		update_ui()
	elif event.is_action_pressed("ui_accept"):
		start_game()
	elif event.is_action_pressed("p1_ultimate"):
		show_lb = true
		update_ui()
	elif event.is_action_pressed("ui_cancel"):
		show_exit = true
		$UI/ExitPanel.visible = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_V:
		show_help = true
		$UI/HelpPanel.visible = true

func start_game():
	GameState.mode = selected
	GameState.maze_size = modes[selected]["size"]
	GameState.time_limit = modes[selected]["time"]
	GameState.item_count = modes[selected]["items"]
	GameState.enemy_count = modes[selected]["enemies"]
	GameState.treasure_count = 0
	GameState.coin_count = 0
	get_tree().change_scene_to_file("res://scenes/MazeGame.tscn")
