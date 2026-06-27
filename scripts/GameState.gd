extends Node
class_name GameState

static var mode: int = 0
static var maze_size: int = 60
static var time_limit: int = 600
static var treasure_count: int = 5
static var coin_count: int = 50
static var item_count: int = 0
static var enemy_count: int = 0
static var is_multi: bool = false
static var is_host: bool = false
static var is_race: bool = false
static var join_ip: String = ""

static var score: int = 0
static var player_collected: int = 0
static var time_remaining: float = 0
static var game_over: bool = false

static var player_speed_mult: float = 1.0
static var fog_boost: float = 0.0
static var magnet_active: bool = false
static var score_mult: float = 1.0

# 画面设置
static var display_width: int = 1920
static var display_height: int = 1080
static var window_mode: int = 3

static func load_display_settings():
	var file = FileAccess.open("user://display_settings.json", FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data != null:
		display_width = data.get("width", 1920)
		display_height = data.get("height", 1080)
		var m = data.get("mode", 3)
		# 旧版 bug：mode 直接存了 display_mode_idx (0/1/2)，导致 1=最小化 2=最大化
		# 合法值只能是 DisplayServer 窗口模式枚举: 0,3,4
		if m in [0, 3, 4]:
			window_mode = m
		else:
			window_mode = 3

static func save_display_settings():
	var data = {"width": display_width, "height": display_height, "mode": window_mode}
	var file = FileAccess.open("user://display_settings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

static func apply_display():
	if DisplayServer.window_get_mode() != window_mode:
		DisplayServer.window_set_mode(window_mode)
	DisplayServer.window_set_size(Vector2i(display_width, display_height))

static func reset():
	score = 0
	player_collected = 0
	time_remaining = time_limit
	game_over = false
	player_speed_mult = 1.0
	fog_boost = 0.0
	magnet_active = false
	score_mult = 1.0
