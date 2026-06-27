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
var show_network = false
var show_room = false
var show_friends = false
var show_nickname = false
var show_item_select = false
var net_mode = 0
var room_code = ""
var my_nickname = ""

func _ready():
	$UI/BG.size = DisplayServer.screen_get_size()
	$UI/ExitPanel.visible = false
	$UI/HelpPanel.visible = false
	$UI/NetworkPanel.visible = false
	$UI/RoomPanel.visible = false
	$UI/FriendPanel.visible = false
	$UI/NickPanel.visible = false
	GameState.load_display_settings()
	var p = load("res://scripts/PlayerProfile.gd")
	my_nickname = p.get_nickname()
	$UI/NickLabel.text = my_nickname
	$UI/NickLabel.visible = true
	$UI/ExitPanel/QuitBtn.pressed.connect(func(): get_tree().quit())
	$UI/ExitPanel/SettingsBtn.pressed.connect(func(): show_exit = false; $UI/ExitPanel.visible = false; $UI/SettingsPanel.open())
	$UI/ExitPanel/ContinueBtn.pressed.connect(func(): show_exit = false; $UI/ExitPanel.visible = false)
	$UI/SettingsBtn.pressed.connect(func(): $UI/SettingsPanel.open())
	$UI/NetworkPanel/SoloBtn.pressed.connect(func(): start_game(false, false, false))
	$UI/NetworkPanel/CoopBtn.pressed.connect(func(): show_room_options(0))
	$UI/NetworkPanel/RaceBtn.pressed.connect(func(): show_room_options(1))
	$UI/NetworkPanel/CodeJoinBtn.pressed.connect(show_code_join)
	$UI/RoomPanel/CreateBtn.pressed.connect(create_room)
	$UI/RoomPanel/JoinBtn.pressed.connect(join_room)
	$UI/RoomPanel/CodeJoin/CodeBtn.pressed.connect(code_join)
	$UI/RoomPanel/StartBtn.pressed.connect(func(): start_game(true, true, net_mode == 1))
	$UI/RoomPanel/BackBtn.pressed.connect(func(): show_room = false; $UI/RoomPanel.visible = false)
	$UI/RoomPanel/FriendsBtn.pressed.connect(show_friend_list)
	$UI/FriendPanel/AddBtn.pressed.connect(add_friend)
	$UI/FriendPanel/CloseBtn.pressed.connect(func(): show_friends = false; $UI/FriendPanel.visible = false)
	$UI/NickPanel/SetBtn.pressed.connect(set_nickname)
	$UI/NickPanel/CloseBtn.pressed.connect(func(): show_nickname = false; $UI/NickPanel.visible = false)
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
			show_network_panel()
		else:
			selected = idx
			update_ui()

func _input(event):
	if show_help:
		if event.is_action_pressed("ui_cancel"):
			show_help = false; $UI/HelpPanel.visible = false
		return
	if show_friends:
		if event.is_action_pressed("ui_cancel"):
			show_friends = false; $UI/FriendPanel.visible = false
		return
	if show_nickname:
		if event.is_action_pressed("ui_accept"):
			set_nickname()
		elif event.is_action_pressed("ui_cancel"):
			show_nickname = false; $UI/NickPanel.visible = false
		return
	if show_room:
		if event.is_action_pressed("ui_cancel"):
			show_room = false; $UI/RoomPanel.visible = false
		return
	if show_exit:
		if event.is_action_pressed("ui_cancel"):
			show_exit = false; $UI/ExitPanel.visible = false
		return
	if show_network:
		if event.is_action_pressed("ui_cancel"):
			show_network = false; $UI/NetworkPanel.visible = false
		return
	if $UI/SettingsPanel.visible:
		return
	if show_lb:
		if event.is_action_pressed("p1_ultimate") or event.is_action_pressed("ui_cancel"):
			show_lb = false; update_ui()
		elif event.is_action_pressed("move_left"):
			selected = wrapi(selected - 1, 0, 3); update_ui()
		elif event.is_action_pressed("move_right"):
			selected = wrapi(selected + 1, 0, 3); update_ui()
		return

	if event.is_action_pressed("move_up"):
		selected = wrapi(selected - 1, 0, 3); update_ui()
	elif event.is_action_pressed("move_down"):
		selected = wrapi(selected + 1, 0, 3); update_ui()
	elif event.is_action_pressed("ui_accept"):
		show_network_panel()
	elif event.is_action_pressed("p1_ultimate"):
		show_lb = true; update_ui()
	elif event.is_action_pressed("ui_cancel"):
		show_exit = true; $UI/ExitPanel.visible = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_V:
		show_help = true; $UI/HelpPanel.visible = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_N:
		show_nickname = true; $UI/NickPanel.visible = true; $UI/NickPanel/NameInput.text = my_nickname

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos = $UI/NickLabel.get_local_mouse_position()
		if mpos.x >= 0 and mpos.x <= 200 and mpos.y >= 0 and mpos.y <= 30:
			show_nickname = true; $UI/NickPanel.visible = true; $UI/NickPanel/NameInput.text = my_nickname

func show_network_panel():
	show_network = true
	$UI/NetworkPanel.visible = true

func show_room_options(mode: int):
	net_mode = mode
	show_network = false; $UI/NetworkPanel.visible = false
	show_room = true; $UI/RoomPanel.visible = true
	$UI/RoomPanel/Title.text = "联机合作" if mode == 0 else "联机比赛"
	$UI/RoomPanel/CreateBtn.visible = true
	$UI/RoomPanel/JoinBtn.visible = true
	$UI/RoomPanel/IPInput.visible = true
	$UI/RoomPanel/CodeJoin.visible = false
	$UI/RoomPanel/RoomCode.visible = false
	$UI/RoomPanel/IPLabel.visible = false
	$UI/RoomPanel/StartBtn.visible = false
	$UI/RoomPanel/FriendsBtn.visible = true
	$UI/RoomPanel/BackBtn.visible = true

func show_code_join():
	show_network = false; $UI/NetworkPanel.visible = false
	show_room = true; $UI/RoomPanel.visible = true
	$UI/RoomPanel/Title.text = "输入房间码加入"
	$UI/RoomPanel/CreateBtn.visible = false
	$UI/RoomPanel/JoinBtn.visible = false
	$UI/RoomPanel/IPInput.visible = false
	$UI/RoomPanel/CodeJoin.visible = true
	$UI/RoomPanel/RoomCode.visible = false
	$UI/RoomPanel/IPLabel.visible = false
	$UI/RoomPanel/StartBtn.visible = false
	$UI/RoomPanel/FriendsBtn.visible = false
	$UI/RoomPanel/BackBtn.visible = true

func create_room():
	room_code = str(randi_range(100000, 999999))
	NetworkManager.start_host()
	$UI/RoomPanel/RoomCode.text = room_code
	$UI/RoomPanel/RoomCode.visible = true
	$UI/RoomPanel/IPLabel.text = my_nickname + "  |  局域网IP: " + NetworkManager.get_local_ip() + "\n正在尝试 UPnP 端口映射..."
	$UI/RoomPanel/IPLabel.visible = true
	$UI/RoomPanel/StartBtn.visible = true
	$UI/RoomPanel/CreateBtn.visible = false
	$UI/RoomPanel/JoinBtn.visible = false
	$UI/RoomPanel/IPInput.visible = false
	$UI/RoomPanel/CodeJoin.visible = false
	NetworkManager.upnp_status.connect(_on_upnp_status)

func _on_upnp_status(success: bool, message: String):
	if success:
		$UI/RoomPanel/IPLabel.text = my_nickname + "  |  局域网IP: " + NetworkManager.get_local_ip() + "\n公网IP: " + message
	else:
		$UI/RoomPanel/IPLabel.text = my_nickname + "  |  局域网IP: " + NetworkManager.get_local_ip() + "\n" + message

func join_room():
	var ip = $UI/RoomPanel/IPInput.text
	GameState.join_ip = ip
	start_game(true, false, net_mode == 1)

func code_join():
	var ip = $UI/RoomPanel/CodeJoin/IPInput2.text
	GameState.join_ip = ip
	start_game(true, false, false)

func show_friend_list():
	show_friends = true; $UI/FriendPanel.visible = true
	refresh_friend_list()

func refresh_friend_list():
	var FriendManager = load("res://scripts/FriendManager.gd")
	var friends = FriendManager.get_friends()
	var list = $UI/FriendPanel/FriendList
	var text = ""
	for fr in friends:
		text += fr["nick"] + "  [" + fr["ip"] + "]\n"
	list.text = text

func add_friend():
	var FriendManager = load("res://scripts/FriendManager.gd")
	var nick = $UI/FriendPanel/NickInput.text
	var ip = $UI/FriendPanel/IPInput.text
	if nick != "" and ip != "":
		FriendManager.add_friend(nick, ip)
		$UI/FriendPanel/NickInput.text = ""
		$UI/FriendPanel/IPInput.text = ""
		refresh_friend_list()

func set_nickname():
	var name = $UI/NickPanel/NameInput.text.strip_edges()
	if name != "" and name.length() <= 6:
		my_nickname = name
		var p = load("res://scripts/PlayerProfile.gd")
		p.set_nickname(name)
		$UI/NickLabel.text = name
		show_nickname = false; $UI/NickPanel.visible = false

func start_game(multi: bool, as_host: bool, is_race: bool):
	GameState.mode = selected
	GameState.maze_size = modes[selected]["size"]
	GameState.time_limit = modes[selected]["time"]
	GameState.item_count = modes[selected]["items"]
	GameState.enemy_count = modes[selected]["enemies"]
	GameState.is_multi = multi
	GameState.is_host = as_host
	GameState.is_race = is_race
	get_tree().change_scene_to_file("res://scenes/MazeGame.tscn")
